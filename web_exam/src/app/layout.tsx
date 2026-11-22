import type { Metadata } from "next";
import "./globals.css";
import { PortalPreferencesProvider } from "@/lib/portal-preferences";

export const metadata: Metadata = {
  title: "Test2Hire - Secure Assessment Platform",
  description: "Official online assessment engine for Test2Hire candidates.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <body className="antialiased min-h-screen flex flex-col">
        <PortalPreferencesProvider>{children}</PortalPreferencesProvider>
      </body>
    </html>
  );
}
