# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"
require "tmpdir"

# The hook denies tool calls, so a mistake in it blocks work rather than failing
# loudly - and the routes it has to cover (a wrapper command, the REST and GraphQL
# routes, an MCP tool from a differently-named server) are easy to widen wrongly.
RSpec.describe ".claude/hooks/pr-guardrails.sh" do
  let(:subcommand) { "gh pr merge" }
  let(:hook) { File.expand_path("../.claude/hooks/pr-guardrails.sh", __dir__) }
  let(:transcript) { Tempfile.new(["transcript", ".jsonl"]).tap { it.write(transcript_body) && it.flush } }
  let(:transcript_body) { "nothing here\n" }
  let(:pr_skill_loaded) { %({"message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"pr"}}]}}\n) }

  # Blocking is exit 2 with the reason on stderr; anything else is a pass.
  def verdict(tool_name, command = nil, env: {})
    payload = {tool_name:, tool_input: command ? {command:} : {}, transcript_path: transcript.path}
    _, err, status = Open3.capture3(env, "/bin/bash", hook, stdin_data: payload.to_json)
    return :allow unless status.exitstatus == 2
    err.include?("never the agent") ? :merge_denied : :skill_required
  end

  describe "merging" do
    it "denies every route, including through a wrapper" do
      expect(verdict("Bash", "#{subcommand} 4397")).to eq :merge_denied
      expect(verdict("Bash", "#{subcommand} --auto --squash 4397")).to eq :merge_denied
      expect(verdict("Bash", "cd /tmp && #{subcommand} 4397")).to eq :merge_denied
      expect(verdict("Bash", "bash -c '#{subcommand} 4397'")).to eq :merge_denied
      expect(verdict("Bash", "echo 4397 | xargs #{subcommand}")).to eq :merge_denied
      expect(verdict("Bash", "gh api -X PUT repos/o/r/pulls/4397/merge")).to eq :merge_denied
      # "github" contains no "gh", so this one reaches the check via "merge"
      expect(verdict("Bash", "curl -XPUT https://api.github.com/repos/o/r/pulls/4397/merge")).to eq :merge_denied
      expect(verdict("Bash", "gh api graphql -f query='mutation{mergePullRequest(input:{})}'")).to eq :merge_denied
      expect(verdict("mcp__github__merge_pull_request")).to eq :merge_denied
      expect(verdict("mcp__gh2__merge_pull_request")).to eq :merge_denied
    end

    context "with the pr skill already loaded" do
      let(:transcript_body) { pr_skill_loaded }

      it "still denies, because nothing clears this half" do
        expect(verdict("Bash", "#{subcommand} 4397")).to eq :merge_denied
        expect(verdict("mcp__github__merge_pull_request")).to eq :merge_denied
      end
    end
  end

  describe "authoring" do
    it "denies until the pr skill is loaded" do
      expect(verdict("Bash", "gh pr create --base main")).to eq :skill_required
      expect(verdict("Bash", "gh pr edit 4397 --body-file b")).to eq :skill_required
      expect(verdict("mcp__github__create_pull_request")).to eq :skill_required
    end

    context "with the pr skill loaded" do
      let(:transcript_body) { pr_skill_loaded }

      it "allows" do
        expect(verdict("Bash", "gh pr create --base main")).to eq :allow
      end
    end

    it "is not satisfied by the hook's own source reaching the transcript" do
      transcript.write(File.read(hook))
      transcript.flush
      expect(verdict("Bash", "gh pr create")).to eq :skill_required
    end
  end

  # The CI image is ruby:slim, which has no jq - and a guard that quietly stops
  # guarding where a tool is missing is worse than no guard.
  it "works with nothing on PATH but grep" do
    bare = Dir.mktmpdir
    grep = ["/bin/grep", "/usr/bin/grep"].find { File.executable?(it) }
    File.symlink(grep, File.join(bare, "grep"))
    only_grep = {"PATH" => bare}
    expect(verdict("Bash", "#{subcommand} 4397", env: only_grep)).to eq :merge_denied
    expect(verdict("Bash", "gh pr create --base main", env: only_grep)).to eq :skill_required
    expect(verdict("mcp__github__create_pull_request", env: only_grep)).to eq :skill_required
    expect(verdict("Bash", "git status", env: only_grep)).to eq :allow
  end

  it "leaves reads, comments and unrelated commands alone" do
    expect(verdict("Bash", "gh pr view 4397 --json mergeable")).to eq :allow
    expect(verdict("Bash", "gh pr checks 4397")).to eq :allow
    expect(verdict("Bash", "gh pr diff 4397")).to eq :allow
    expect(verdict("Bash", "gh pr comment 4397 -F body.md")).to eq :allow
    expect(verdict("Bash", "git merge --no-edit origin/main")).to eq :allow
    expect(verdict("Bash", "grep submerged notes.txt")).to eq :allow
    expect(verdict("Bash", "git status")).to eq :allow
    expect(verdict("mcp__github__list_pull_requests")).to eq :allow
  end
end
