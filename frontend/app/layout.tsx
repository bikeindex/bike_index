import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Bike Marketplace",
  description: "Bike registration, theft reporting, and marketplace",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
