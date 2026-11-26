"use client";

import React, { useEffect, useState, useCallback } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { auth, db } from "@/lib/firebase";
import {
  resolveUserRole,
  signOutPortalUser,
  resendCompanyVerificationEmail,
  reloadCompanyUser,
} from "@/lib/auth-service";
import { onAuthStateChanged, User } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { CompanyProvider, useCompany } from "@/lib/i18n";
import { formatTimestamp } from "@/lib/formatters";
import {
  listenCompanyNotifications,
  markNotificationAsRead,
  markAllCompanyNotificationsAsRead,
  deleteCompanyNotification,
  clearAllCompanyNotifications,
  CompanyNotification,
} from "@/lib/company-portal-service";
import {
  LayoutDashboard,
  Briefcase,
  Users,
  FileQuestion,
  Calendar,
  Award,
  Building2,
  LogOut,
  CheckCircle2,
  XCircle,
  Menu,
  X,
  Sun,
  Moon,
  Globe,
  Sparkles,
  Bell,
  CheckCheck,
  Trash2,
  Heart,
  MessageSquare,
  Mail,
  RefreshCw,
} from "lucide-react";

function CompanyPortalNavContent({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const { t, language, toggleLanguage, theme, toggleTheme, isRTL, setCompanyInfo } = useCompany();

  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [emailVerified, setEmailVerified] = useState<boolean>(true);
  const [checkingVerification, setCheckingVerification] = useState(false);
  const [resendingVerification, setResendingVerification] = useState(false);
  const [verificationNotice, setVerificationNotice] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);
  const [companyData, setCompanyData] = useState<{
    name: string;
    logoUrl?: string;
    verificationStatus?: string;
  } | null>(null);
  const [loading, setLoading] = useState(true);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [logoError, setLogoError] = useState(false);

  // Real-time Company Notifications
  const [notifications, setNotifications] = useState<CompanyNotification[]>([]);
  const [notifOpen, setNotifOpen] = useState(false);
  const notifContainerRef = React.useRef<HTMLDivElement>(null);
  const [toastNotif, setToastNotif] = useState<CompanyNotification | null>(null);
  const initialNotifLoaded = React.useRef(false);
  const prevNotifIds = React.useRef<Set<string>>(new Set());
  const unreadCount = notifications.filter((n) => !n.isRead).length;

  useEffect(() => {
    setLogoError(false);
  }, [companyData?.logoUrl]);

  useEffect(() => {
    if (!notifOpen) return;
    const handleOutsideClick = (event: MouseEvent) => {
      if (
        notifContainerRef.current &&
        !notifContainerRef.current.contains(event.target as Node)
      ) {
        setNotifOpen(false);
      }
    };
    document.addEventListener("mousedown", handleOutsideClick);
    return () => document.removeEventListener("mousedown", handleOutsideClick);
  }, [notifOpen]);

  const handleNotificationsUpdate = useCallback((items: CompanyNotification[]) => {
    if (initialNotifLoaded.current) {
      const newlyArrived = items.find(
        (i) => !prevNotifIds.current.has(i.id) && !i.isRead
      );
      if (newlyArrived) {
        setToastNotif(newlyArrived);
      }
    }
    prevNotifIds.current = new Set(items.map((i) => i.id));
    initialNotifLoaded.current = true;
    setNotifications(items);
  }, []);

  useEffect(() => {
    if (!toastNotif) return;
    const timer = setTimeout(() => {
      setToastNotif(null);
    }, 6000);
    return () => clearTimeout(timer);
  }, [toastNotif]);

  const getNotificationIcon = (type?: string) => {
    if (type?.includes("LIKE")) return <Heart className="w-4 h-4 text-rose-500 fill-rose-500" />;
    if (type?.includes("COMMENT")) return <MessageSquare className="w-4 h-4 text-indigo-500" />;
    if (type?.includes("INTERVIEW")) return <Calendar className="w-4 h-4 text-blue-500" />;
    if (type?.includes("OFFER")) return <Award className="w-4 h-4 text-emerald-500" />;
    return <Bell className="w-4 h-4 text-amber-500" />;
  };

  const fetchCompanyDetails = useCallback(
    async (uid: string, fallbackName?: string) => {
      try {
        const compSnap = await getDoc(doc(db, "companies", uid));
        if (compSnap.exists()) {
          const d = compSnap.data();
          const info = {
            name: d.name || d.companyName || fallbackName || "My Company",
            logoUrl: d.logoUrl || d.logo || "",
            industry: d.industry || "",
            verificationStatus: (d.verificationStatus || "PENDING").toUpperCase(),
          };
          setCompanyData(info);
          setCompanyInfo(info);
          setLogoError(false);
        } else {
          const fallbackInfo = {
            name: fallbackName || "My Company",
            logoUrl: "",
            verificationStatus: "PENDING",
          };
          setCompanyData(fallbackInfo);
          setCompanyInfo(fallbackInfo);
        }
      } catch (err) {
        console.error("Failed to fetch company profile for branding:", err);
      }
    },
    [setCompanyInfo]
  );

  useEffect(() => {
    let notifUnsub: (() => void) | null = null;

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        router.push("/login");
        return;
      }

      // Listen for company notifications
      if (notifUnsub) notifUnsub();
      notifUnsub = listenCompanyNotifications(user.uid, handleNotificationsUpdate);

      try {
        const resolved = await resolveUserRole(user);
        if (resolved.role !== "COMPANY") {
          if (resolved.role === "ADMIN") {
            router.push("/dashboard/companies");
            return;
          }
          await signOutPortalUser();
          router.push("/login?error=unauthorized_role");
          return;
        }

        setCurrentUser(user);
        setEmailVerified(Boolean(user.emailVerified));
        const info = {
          name: resolved.companyName || "My Company",
          logoUrl: resolved.logoUrl || "",
          industry: resolved.industry || "",
          verificationStatus: resolved.verificationStatus || "PENDING",
        };
        setCompanyData(info);
        setCompanyInfo(info);
        setLogoError(false);
      } catch (err) {
        console.error("Failed to verify company session:", err);
        router.push("/login");
      } finally {
        setLoading(false);
      }
    });

    const handleProfileUpdated = () => {
      if (auth.currentUser) {
        fetchCompanyDetails(auth.currentUser.uid);
      }
    };
    window.addEventListener("company-profile-updated", handleProfileUpdated);

    return () => {
      unsubscribe();
      if (notifUnsub) notifUnsub();
      window.removeEventListener("company-profile-updated", handleProfileUpdated);
    };
  }, [router, fetchCompanyDetails, setCompanyInfo]);

  const resolveNotificationHref = useCallback((n: CompanyNotification): string => {
    const raw = (n.link || n.actionUrl || "").trim();
    if (raw === "/community" || raw.startsWith("/community?")) {
      return "/company/community";
    }
    if (raw.startsWith("/")) {
      return raw;
    }
    const upperType = String(n.type || "").toUpperCase();
    const d = (n.data && typeof n.data === "object" ? n.data : {}) as Record<string, any>;
    if (upperType.includes("COMMUNITY")) {
      return "/company/community";
    }
    if (upperType.includes("OFFER")) {
      const offerId = String(d.offerId || n.entityId || "").trim();
      return offerId ? `/company/offers?offerId=${encodeURIComponent(offerId)}` : "/company/offers";
    }
    if (upperType.includes("INTERVIEW")) {
      const interviewId = String(d.interviewId || n.entityId || "").trim();
      return interviewId ? `/company/interviews?interviewId=${encodeURIComponent(interviewId)}` : "/company/interviews";
    }
    if (upperType.includes("CHALLENGE") || upperType.includes("ASSIGNMENT")) {
      return "/company/exams?tab=challenges";
    }
    if (upperType.includes("APPLICATION") || upperType.includes("EXAM")) {
      const params = new URLSearchParams();
      const appId = String(d.applicationId || (upperType.includes("APPLICATION") ? n.entityId || "" : "")).trim();
      const candId = String(d.candidateId || "").trim();
      const jobId = String(d.jobId || "").trim();
      if (appId) params.set("applicationId", appId);
      if (candId) params.set("candidateId", candId);
      if (jobId) params.set("jobId", jobId);
      const qs = params.toString();
      return qs ? `/company/applicants?${qs}` : "/company/applicants";
    }
    if (upperType.includes("COMPANY")) {
      return "/company/profile";
    }
    return "/company/dashboard";
  }, []);

  const handleNotificationNavigate = useCallback(
    (n: CompanyNotification) => {
      if (!n.isRead) {
        void markNotificationAsRead(n.id);
      }
      const targetUrl = resolveNotificationHref(n);
      router.push(targetUrl);
      setNotifOpen(false);
    },
    [resolveNotificationHref, router]
  );

  const handleCheckVerification = async () => {
    setCheckingVerification(true);
    setVerificationNotice(null);
    try {
      const verified = await reloadCompanyUser();
      setEmailVerified(verified);
      if (!verified) {
        setVerificationNotice({
          type: "error",
          text:
            language === "ar"
              ? "لم يتم تأكيد البريد الإلكتروني بعد. يرجى فتح الرسالة المرسلة لبريدك والنقر على رابط التفعيل."
              : "Your email is not verified yet. Please open your inbox and click the verification link.",
        });
      }
    } catch (err: any) {
      setVerificationNotice({
        type: "error",
        text: err?.message || t("error"),
      });
    } finally {
      setCheckingVerification(false);
    }
  };

  const handleResendVerification = async () => {
    setResendingVerification(true);
    setVerificationNotice(null);
    try {
      await resendCompanyVerificationEmail();
      setVerificationNotice({
        type: "success",
        text:
          language === "ar"
            ? "تمت إعادة إرسال رابط التفعيل إلى بريدك الإلكتروني بنجاح."
            : "Verification email resent! Please check your inbox and spam folder.",
      });
    } catch (err: any) {
      setVerificationNotice({
        type: "error",
        text: err?.message || t("error"),
      });
    } finally {
      setResendingVerification(false);
    }
  };

  const handleSignOut = async () => {
    try {
      await signOutPortalUser();
      router.push("/login");
    } catch (err) {
      console.error("Sign out error:", err);
    }
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50 dark:bg-[#090d16] text-slate-900 dark:text-white transition-colors duration-200">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-sm font-medium text-slate-600 dark:text-slate-300">
            {language === "ar" ? "جاري تحميل بوابة الشركات..." : "Loading Employer Portal..."}
          </p>
        </div>
      </div>
    );
  }

  const navItems = [
    { name: t("navDashboard"), href: "/company/dashboard", icon: LayoutDashboard },
    { name: t("navJobs"), href: "/company/jobs", icon: Briefcase },
    { name: t("navApplicants"), href: "/company/applicants", icon: Users },
    { name: t("navExams"), href: "/company/exams", icon: FileQuestion },
    { name: t("navInterviews"), href: "/company/interviews", icon: Calendar },
    { name: t("navOffers"), href: "/company/offers", icon: Award },
    { name: language === "ar" ? "المجتمع المهني" : "Community", href: "/company/community", icon: Sparkles },
    { name: t("navProfile"), href: "/company/profile", icon: Building2 },
  ];

  return (
    <div
      dir={isRTL ? "rtl" : "ltr"}
      className="min-h-screen bg-slate-50 dark:bg-[#090d16] text-slate-900 dark:text-slate-100 flex flex-col font-sans transition-colors duration-200"
    >
      {/* Top Header */}
      <header className="bg-white/95 dark:bg-[#0c121e]/95 text-slate-900 dark:text-white border-b border-slate-200/80 dark:border-slate-800/80 sticky top-0 z-50 shadow-[0_1px_3px_rgba(0,0,0,0.05)] backdrop-blur-md transition-colors duration-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3 sm:gap-4">
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="lg:hidden p-2 text-slate-600 hover:text-slate-900 dark:text-slate-300 dark:hover:text-white rounded-lg focus:outline-none"
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>

            <Link href="/company/dashboard" className="flex items-center gap-3 group">
              {companyData?.logoUrl && !logoError ? (
                <div className="relative w-10 h-10 rounded-xl overflow-hidden border border-slate-200 dark:border-slate-700 bg-white shadow-sm flex-shrink-0">
                  <img
                    src={companyData.logoUrl}
                    alt={companyData.name}
                    loading="lazy"
                    decoding="async"
                    className="w-full h-full object-cover"
                    onError={() => setLogoError(true)}
                  />
                </div>
              ) : (
                <div className="w-10 h-10 bg-gradient-to-tr from-indigo-600 via-indigo-500 to-blue-500 text-white rounded-xl flex items-center justify-center font-bold text-sm tracking-wider shadow-sm flex-shrink-0">
                  {companyData?.name ? companyData.name.slice(0, 2).toUpperCase() : "CO"}
                </div>
              )}
              <div className="flex flex-col">
                <span className="font-bold text-sm sm:text-base tracking-tight flex items-center gap-2">
                  <span className="text-slate-900 dark:text-white">Test2Hire</span>
                  <span className="text-[10px] sm:text-[11px] font-semibold px-2 py-0.5 bg-indigo-50 dark:bg-indigo-500/20 text-indigo-600 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-500/30 rounded-full">
                    {t("portalTitle")}
                  </span>
                </span>
                <span className="text-[11px] text-slate-500 dark:text-slate-400 font-medium truncate max-w-[160px] sm:max-w-[220px]">
                  {companyData?.name}
                </span>
              </div>
            </Link>
          </div>

          <div className="flex items-center gap-2 sm:gap-3">
            {/* Verification Status Badge */}
            {(() => {
              const status = (companyData?.verificationStatus || "").toUpperCase();
              if (status === "SUSPENDED") {
                return (
                  <div className="hidden sm:flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-rose-50 dark:bg-rose-950/70 text-rose-700 dark:text-rose-400 border border-rose-200 dark:border-rose-800/80">
                    <XCircle className="w-3.5 h-3.5" />
                    <span>{language === "ar" ? "حساب موقوف" : "Account Suspended"}</span>
                  </div>
                );
              }
              if (status === "APPROVED" || emailVerified) {
                return (
                  <div className="hidden sm:flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 dark:bg-emerald-950/70 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800/80">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>
                      {status === "APPROVED"
                        ? t("verifiedCompany")
                        : language === "ar"
                        ? "بريد موثّق"
                        : "Email Verified"}
                    </span>
                  </div>
                );
              }
              return (
                <div className="hidden sm:flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-amber-50 dark:bg-amber-950/70 text-amber-700 dark:text-amber-400 border border-amber-200 dark:border-amber-800/80">
                  <Sparkles className="w-3.5 h-3.5" />
                  <span>{language === "ar" ? "بانتظار تأكيد البريد" : "Verify Email"}</span>
                </div>
              );
            })()}

            {/* Language Switcher */}
            <button
              onClick={toggleLanguage}
              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 text-xs font-semibold rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
              title="تغيير اللغة / Switch Language"
            >
              <Globe className="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400" />
              <span>{t("langToggle")}</span>
            </button>

            {/* Theme Toggle (Light / Dark) */}
            <button
              onClick={toggleTheme}
              className="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
              title={theme === "dark" ? t("themeToggleLight") : t("themeToggleDark")}
              aria-label="Toggle Theme"
            >
              {theme === "dark" ? (
                <Sun className="w-4 h-4 text-amber-400" />
              ) : (
                <Moon className="w-4 h-4 text-indigo-600" />
              )}
            </button>

            {/* Real-time Notifications Bell */}
            <div className="relative" ref={notifContainerRef}>
              <button
                onClick={() => setNotifOpen(!notifOpen)}
                className="relative p-2 rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 transition-colors cursor-pointer"
                title={language === "ar" ? "الإشعارات" : "Notifications"}
                aria-label="Notifications"
              >
                <Bell className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-rose-500 text-[9px] font-bold text-white shadow-sm ring-2 ring-white dark:ring-slate-900 animate-pulse">
                    {unreadCount > 9 ? "9+" : unreadCount}
                  </span>
                )}
              </button>

              {/* Notifications Dropdown Popover */}
              {notifOpen && (
                <div
                  className={`absolute ${
                    isRTL ? "left-0" : "right-0"
                  } mt-2 w-80 sm:w-96 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 shadow-2xl z-50 overflow-hidden text-slate-800 dark:text-slate-100 animate-in fade-in zoom-in-95`}
                >
                  <div className="flex items-center justify-between px-4 py-3 bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700">
                    <div className="flex items-center gap-2">
                      <Bell className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                      <span className="text-xs font-bold text-slate-900 dark:text-white">
                        {language === "ar" ? "مركز الإشعارات" : "Notifications Center"}
                      </span>
                      {unreadCount > 0 && (
                        <span className="px-1.5 py-0.5 text-[10px] font-semibold bg-rose-50 dark:bg-rose-500/20 text-rose-600 dark:text-rose-300 rounded-full border border-rose-200 dark:border-rose-500/30">
                          {unreadCount} {language === "ar" ? "جديد" : "new"}
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      {unreadCount > 0 && currentUser && (
                        <button
                          onClick={() => markAllCompanyNotificationsAsRead(currentUser.uid)}
                          className="inline-flex items-center gap-1 text-[11px] text-slate-500 hover:text-indigo-600 dark:text-slate-400 dark:hover:text-indigo-300 transition-colors cursor-pointer"
                          title={language === "ar" ? "تحديد الكل كمقروء" : "Mark all as read"}
                        >
                          <CheckCheck className="w-3.5 h-3.5" />
                          <span>{language === "ar" ? "قراءة الكل" : "Mark read"}</span>
                        </button>
                      )}
                      {notifications.length > 0 && currentUser && (
                        <button
                          onClick={() => {
                            if (window.confirm(language === "ar" ? "هل أنت متأكد من رغبتك في حذف جميع الإشعارات؟" : "Are you sure you want to delete all notifications?")) {
                              clearAllCompanyNotifications(currentUser.uid);
                            }
                          }}
                          className="inline-flex items-center gap-1 text-[11px] text-slate-500 hover:text-rose-600 dark:text-slate-400 dark:hover:text-rose-400 transition-colors cursor-pointer"
                          title={language === "ar" ? "حذف جميع الإشعارات" : "Clear all notifications"}
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                          <span>{language === "ar" ? "حذف الكل" : "Clear all"}</span>
                        </button>
                      )}
                    </div>
                  </div>

                  <div className="max-h-80 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-800">
                    {notifications.length === 0 ? (
                      <div className="p-6 text-center text-xs text-slate-500 dark:text-slate-400">
                        {language === "ar" ? "لا توجد إشعارات جديدة حالياً" : "No notifications yet."}
                      </div>
                    ) : (
                      notifications.map((n) => (
                        <div
                          key={n.id}
                          onClick={() => handleNotificationNavigate(n)}
                          className={`p-3.5 transition-colors cursor-pointer flex items-start gap-3 ${
                            !n.isRead
                              ? "bg-indigo-50/60 dark:bg-indigo-950/30 hover:bg-indigo-50 dark:hover:bg-indigo-950/50"
                              : "hover:bg-slate-50 dark:hover:bg-slate-800/40"
                          }`}
                        >
                          <div className="mt-0.5 p-2 rounded-xl bg-slate-100 dark:bg-slate-800 flex-shrink-0">
                            {getNotificationIcon(n.type)}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between gap-1">
                              <p className="text-xs font-semibold text-slate-900 dark:text-white truncate">
                                {n.title}
                              </p>
                              {!n.isRead && (
                                <span className="w-2 h-2 rounded-full bg-indigo-600 dark:bg-indigo-400 flex-shrink-0"></span>
                              )}
                            </div>
                            <p className="text-[11px] text-slate-600 dark:text-slate-300 mt-0.5 line-clamp-2">
                              {n.body}
                            </p>
                            <div className="flex items-center justify-between mt-1.5">
                              <span className="text-[10px] text-slate-400 dark:text-slate-500">
                                {formatTimestamp(
                                  n.createdAt,
                                  language === "ar" ? "ar-SA" : "en-US",
                                  { hour: "2-digit", minute: "2-digit" },
                                  language === "ar" ? "الآن" : "Just now"
                                )}
                              </span>
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  deleteCompanyNotification(n.id);
                                }}
                                className="p-1 rounded hover:bg-rose-100 dark:hover:bg-rose-950/50 text-slate-400 hover:text-rose-600 dark:text-slate-500 dark:hover:text-rose-400 transition-colors cursor-pointer"
                                title={language === "ar" ? "حذف" : "Delete"}
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* User & Sign Out */}
            <div className="hidden md:flex flex-col text-end">
              <span className="text-[10px] text-slate-400">{t("signedInAs")}</span>
              <span className="text-xs font-semibold text-slate-700 dark:text-slate-200 truncate max-w-[140px]">
                {currentUser?.email}
              </span>
            </div>

            <button
              onClick={handleSignOut}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-slate-100 hover:bg-rose-50 hover:text-rose-600 text-slate-700 border border-slate-200 hover:border-rose-200 dark:bg-slate-800 dark:hover:bg-rose-950 dark:hover:text-rose-300 dark:text-slate-300 dark:border-slate-700 dark:hover:border-rose-900 rounded-lg transition-colors cursor-pointer"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">{t("signOut")}</span>
            </button>
          </div>
        </div>

        {/* Desktop Navigation Bar */}
        <div className="hidden lg:block bg-slate-50/90 dark:bg-[#090d16]/90 border-t border-slate-200/80 dark:border-slate-800/80 backdrop-blur-md transition-colors duration-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <nav className="flex space-x-1 rtl:space-x-reverse py-1.5 overflow-x-auto">
              {navItems.map((item) => {
                const isActive =
                  pathname === item.href ||
                  (item.href !== "/company/dashboard" && pathname.startsWith(item.href));
                const Icon = item.icon;
                return (
                  <Link
                    key={item.name}
                    href={item.href}
                    className={`inline-flex items-center gap-2 px-3.5 py-2 rounded-lg text-xs font-medium transition-all whitespace-nowrap ${
                      isActive
                        ? "bg-indigo-600 text-white shadow-sm shadow-indigo-600/30 font-semibold"
                        : "text-slate-600 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-800/80 hover:text-slate-900 dark:hover:text-white"
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{item.name}</span>
                  </Link>
                );
              })}
            </nav>
          </div>
        </div>

        {/* Mobile Navigation Drawer */}
        {mobileMenuOpen && (
          <div className="lg:hidden bg-white dark:bg-[#0c121e] border-t border-slate-200 dark:border-slate-800 px-4 pt-2 pb-4 space-y-1 shadow-lg">
            {navItems.map((item) => {
              const isActive =
                pathname === item.href ||
                (item.href !== "/company/dashboard" && pathname.startsWith(item.href));
              const Icon = item.icon;
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  onClick={() => setMobileMenuOpen(false)}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium ${
                    isActive
                      ? "bg-indigo-600 text-white font-semibold"
                      : "text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800/80 hover:text-slate-900 dark:hover:text-white"
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{item.name}</span>
                </Link>
              );
            })}
          </div>
        )}
      </header>

      {/* Real-time Floating Notification Toast */}
      {toastNotif && (
        <div
          onClick={() => {
            handleNotificationNavigate(toastNotif);
            setToastNotif(null);
          }}
          className={`fixed top-20 ${
            isRTL ? "left-6" : "right-6"
          } z-50 max-w-sm w-full bg-white dark:bg-slate-900 border border-indigo-200 dark:border-indigo-800 shadow-2xl rounded-2xl p-4 cursor-pointer transition-all duration-300 flex items-start gap-3 hover:scale-[1.02]`}
        >
          <div className="p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/60 flex-shrink-0">
            {getNotificationIcon(toastNotif.type)}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between gap-2">
              <span className="text-xs font-bold text-slate-900 dark:text-white truncate">
                {toastNotif.title}
              </span>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setToastNotif(null);
                }}
                className="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 p-0.5 cursor-pointer"
                title={language === "ar" ? "إغلاق" : "Close"}
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
            <p className="text-[11px] text-slate-600 dark:text-slate-300 mt-1 line-clamp-2">
              {toastNotif.body}
            </p>
            <span className="text-[10px] text-indigo-600 dark:text-indigo-400 font-semibold mt-1.5 inline-block">
              {(() => {
                const dest = resolveNotificationHref(toastNotif);
                if (dest.includes("community")) {
                  return language === "ar" ? "اضغط للمعاينة في المجتمع ←" : "Click to view in Community →";
                }
                if (dest.includes("offers")) {
                  return language === "ar" ? "عرض في العروض الوظيفية ←" : "View in Job Offers →";
                }
                if (dest.includes("interviews")) {
                  return language === "ar" ? "عرض في المقابلات ←" : "View in Interviews →";
                }
                if (dest.includes("exams")) {
                  return language === "ar" ? "عرض في الاختبارات والواجبات ←" : "View in Exams & Assignments →";
                }
                if (dest.includes("applicants")) {
                  return language === "ar" ? "فتح ملف المتقدم ←" : "Open Applicant Details →";
                }
                return language === "ar" ? "اضغط لفتح الإشعار ←" : "Click to open →";
              })()}
            </span>
          </div>
        </div>
      )}

      {/* Main Content View */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {currentUser && !emailVerified && companyData?.verificationStatus !== "APPROVED" ? (
          <div className="max-w-lg mx-auto mt-10 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-8 shadow-xl text-center space-y-5">
            <div className="w-16 h-16 rounded-2xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-800 flex items-center justify-center mx-auto">
              <Mail className="w-8 h-8" />
            </div>
            <div className="space-y-2">
              <h2 className="text-xl font-bold text-slate-900 dark:text-white">
                {language === "ar"
                  ? "تأكيد البريد الإلكتروني مطلوب"
                  : "Verify Your Company Email Address"}
              </h2>
              <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed">
                {language === "ar"
                  ? `لضمان أمان وموثوقية حسابات الشركات، تم إرسال رابط تفعيل إلى البريد (${currentUser.email}). يرجى فتح الرسالة والضغط على الرابط ثم النقر أدناه للمتابعة.`
                  : `To prevent unverified company signups, a verification link was sent to (${currentUser.email}). Please verify your inbox link and continue.`}
              </p>
            </div>

            {verificationNotice && (
              <div
                className={`p-3 rounded-xl text-xs font-semibold border ${
                  verificationNotice.type === "success"
                    ? "bg-emerald-50 dark:bg-emerald-950/50 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800"
                    : "bg-rose-50 dark:bg-rose-950/50 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-800"
                }`}
              >
                {verificationNotice.text}
              </div>
            )}

            <div className="flex flex-col gap-2.5">
              <button
                type="button"
                onClick={handleCheckVerification}
                disabled={checkingVerification}
                className="w-full py-3 px-4 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-bold flex items-center justify-center gap-2 cursor-pointer"
              >
                <RefreshCw className={`w-4 h-4 ${checkingVerification ? "animate-spin" : ""}`} />
                <span>
                  {language === "ar"
                    ? "تم تفعيل البريد - تحديث ومتابعة"
                    : "I Verified My Email — Continue"}
                </span>
              </button>
              <button
                type="button"
                onClick={handleResendVerification}
                disabled={resendingVerification}
                className="w-full py-2.5 px-4 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 disabled:opacity-50 text-slate-700 dark:text-slate-200 text-xs font-semibold cursor-pointer"
              >
                {language === "ar"
                  ? "إعادة إرسال رابط التفعيل"
                  : "Resend Verification Email"}
              </button>
              <button
                type="button"
                onClick={handleSignOut}
                className="w-full py-2 text-xs text-rose-600 dark:text-rose-400 font-semibold hover:underline cursor-pointer"
              >
                {t("signOut")}
              </button>
            </div>
          </div>
        ) : (
          children
        )}
      </main>
    </div>
  );
}

export default function CompanyPortalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <CompanyProvider>
      <CompanyPortalNavContent>{children}</CompanyPortalNavContent>
    </CompanyProvider>
  );
}
