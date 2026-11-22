"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { auth } from "@/lib/firebase";
import { signOutAdmin } from "@/lib/admin-auth";
import { resolveUserRole } from "@/lib/auth-service";
import { onAuthStateChanged, User } from "firebase/auth";
import { Menu, X } from "lucide-react";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // Admin Ops dashboard is English LTR light-themed regardless of cached Company Portal preferences
  useEffect(() => {
    const html = document.documentElement;
    html.lang = "en";
    html.dir = "ltr";
    html.classList.remove("dark");

    return () => {
      try {
        const savedLang = (localStorage.getItem("t2h_company_lang") as "ar" | "en") || "ar";
        const savedTheme = localStorage.getItem("t2h_company_theme");
        html.lang = savedLang;
        html.dir = savedLang === "ar" ? "rtl" : "ltr";
        if (savedTheme === "dark") {
          html.classList.add("dark");
        } else {
          html.classList.remove("dark");
        }
      } catch {
        // ignore storage errors
      }
    };
  }, []);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        router.push("/login");
        return;
      }

      try {
        const { role } = await resolveUserRole(user);
        if (role !== "ADMIN") {
          if (role === "COMPANY") {
            router.push("/company/dashboard");
            return;
          }
          await signOutAdmin();
          router.push("/login?error=unauthorized");
          return;
        }
        setCurrentUser(user);
      } catch (err) {
        console.error("Failed to verify admin status with Firebase", err);
        router.push("/login");
      } finally {
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, [router]);

  const handleSignOut = async () => {
    try {
      await signOutAdmin();
      router.push("/login");
    } catch (err) {
      console.error("Failed to sign out", err);
    }
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-sm font-medium text-slate-600">Verifying Admin Session...</p>
        </div>
      </div>
    );
  }

  const navItems = [
    { name: "Companies", href: "/dashboard/companies" },
    { name: "Jobs", href: "/dashboard/jobs" },
    { name: "Exams", href: "/dashboard/exams" },
    { name: "Users", href: "/dashboard/users" },
    { name: "Audit Logs", href: "/dashboard/audit" },
  ];

  return (
    <div dir="ltr" className="min-h-screen bg-slate-50 text-slate-900 flex flex-col">
      {/* Top Navigation */}
      <header className="bg-slate-900 text-white border-b border-slate-800 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-4 md:gap-8">
            <button
              type="button"
              onClick={() => setMobileMenuOpen((prev) => !prev)}
              className="md:hidden p-2 rounded-lg text-slate-300 hover:bg-slate-800 hover:text-white transition-colors"
              aria-label="Toggle navigation menu"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>

            <Link href="/dashboard/companies" className="flex items-center gap-3">
              <div className="w-9 h-9 bg-indigo-600 text-white rounded-lg flex items-center justify-center font-black text-sm tracking-wider shadow">
                T2H
              </div>
              <span className="font-bold text-lg tracking-tight">Test2Hire <span className="text-indigo-400 font-normal text-xs uppercase px-2 py-0.5 bg-indigo-950/80 rounded border border-indigo-800 ml-1">Admin Ops</span></span>
            </Link>

            <nav className="hidden md:flex items-center space-x-1">
              {navItems.map((item) => {
                const isActive = pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.name}
                    href={item.href}
                    className={`px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                      isActive
                        ? "bg-slate-800 text-white border border-slate-700"
                        : "text-slate-300 hover:bg-slate-800/60 hover:text-white"
                    }`}
                  >
                    {item.name}
                  </Link>
                );
              })}
            </nav>
          </div>

          <div className="flex items-center gap-4">
            <div className="hidden sm:flex flex-col text-right">
              <span className="text-xs text-slate-400">Signed in as</span>
              <span className="text-xs font-semibold text-slate-200">{currentUser?.email}</span>
            </div>
            <button
              type="button"
              onClick={handleSignOut}
              className="px-3 py-1.5 text-xs font-medium bg-slate-800 hover:bg-red-950 hover:text-red-300 text-slate-300 border border-slate-700 hover:border-red-900 rounded-lg transition-colors"
            >
              Sign Out
            </button>
          </div>
        </div>

        {/* Mobile Navigation Drawer */}
        {mobileMenuOpen && (
          <nav className="md:hidden bg-slate-900 border-t border-slate-800 px-4 py-3 space-y-1">
            {navItems.map((item) => {
              const isActive = pathname.startsWith(item.href);
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  onClick={() => setMobileMenuOpen(false)}
                  className={`block px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                    isActive
                      ? "bg-slate-800 text-white border border-slate-700"
                      : "text-slate-300 hover:bg-slate-800/60 hover:text-white"
                  }`}
                >
                  {item.name}
                </Link>
              );
            })}
          </nav>
        )}
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>
    </div>
  );
}
