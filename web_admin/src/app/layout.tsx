import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Test2Hire - Enterprise Talent & Assessment Portal",
  description: "Enterprise Recruitment, Assessment, and Hiring Operations Portal.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ar" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var theme = localStorage.getItem('t2h_company_theme');
                  var lang = localStorage.getItem('t2h_company_lang') || 'ar';
                  document.documentElement.lang = lang;
                  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
                  if (theme === 'dark' || (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.classList.add('dark');
                  } else {
                    document.documentElement.classList.remove('dark');
                  }
                } catch (e) {}
              })();
            `,
          }}
        />
      </head>
      <body className="antialiased min-h-screen flex flex-col bg-slate-50 dark:bg-[#090d16] text-slate-900 dark:text-slate-100 transition-colors duration-200">
        {children}
      </body>
    </html>
  );
}
