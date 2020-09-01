import log from "../../utils/log";

function BinxAdminTweet() {
  return {
    init() {
      $("#tweet_kind").on("change", (e) => {
        if ($("#tweet_kind").val() == "imported_tweet") {
          $("#kind-app_tweet").collapse("hide");
          $("#kind-imported_tweet").collapse("show");
        } else if ($("#tweet_kind").val() == "app_tweet") {
          $("#kind-imported_tweet").collapse("hide");
          $("#kind-app_tweet").collapse("show");
          $("#kind-imported_tweet").required;
        }
      });

      $("#checkAll").on("click", (e) => {
        e.preventDefault();
        $("#twitterAccountIds input").prop("checked", true);
      });
      $("#uncheckAll").on("click", (e) => {
        e.preventDefault();
        $("#twitterAccountIds input").prop("checked", false);
      });

      this.setCharacterCount();
      this.characterCounter();
    },

    setCharacterCount() {
      $("#characterTotal").text(
        `${$("#characterCounterField .form-control").val().length}/280`
      );
    },

    characterCounter() {
      $("#characterCounterField .form-control").on("keyup", (e) => {
        e.preventDefault();
        this.setCharacterCount();
      });
    },
  };
}

export default BinxAdminTweet;
