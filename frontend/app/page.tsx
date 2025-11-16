export default function Home() {
  return (
    <div className="min-h-screen p-8">
      <main className="max-w-7xl mx-auto">
        <h1 className="text-4xl font-bold mb-8">Bike Marketplace</h1>
        <p className="text-lg mb-4">
          Welcome to the new Next.js + FastAPI bike marketplace application.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
          <div className="border rounded-lg p-6">
            <h2 className="text-2xl font-semibold mb-2">Register Bikes</h2>
            <p>Register your bike with detailed information and serial number.</p>
          </div>
          <div className="border rounded-lg p-6">
            <h2 className="text-2xl font-semibold mb-2">Report Theft</h2>
            <p>Report stolen bikes and help recover them.</p>
          </div>
          <div className="border rounded-lg p-6">
            <h2 className="text-2xl font-semibold mb-2">Marketplace</h2>
            <p>Buy and sell bikes and components.</p>
          </div>
        </div>
      </main>
    </div>
  );
}
