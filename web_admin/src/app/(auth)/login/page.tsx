"use client";

import React, { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  signInPortalUser,
  registerCompanyPortalUser,
  isValidEmailAddress,
} from "@/lib/auth-service";
import {
  isAllowedRasterImage,
  sanitizeExternalUrl,
  sanitizeImageUrl,
} from "@/lib/formatters";
import {
  Briefcase,
  AlertCircle,
  Loader2,
  Globe,
  Sun,
  Moon,
  Building2,
  Sparkles,
  ShieldCheck,
  BrainCircuit,
  ArrowRight,
  ArrowLeft,
  CheckCircle2,
  Upload,
  Link as LinkIcon,
  Eye,
  EyeOff,
  Image as ImageIcon,
} from "lucide-react";

export default function UnifiedPortalLoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<"login" | "register">("login");

  // Auth fields
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  // Company Registration fields
  const [companyName, setCompanyName] = useState("");
  const [industry, setIndustry] = useState("Technology & Software");
  const [size, setSize] = useState("11-50");
  const [website, setWebsite] = useState("");
  const [country, setCountry] = useState("Jordan");
  const [city, setCity] = useState("Amman");
  const [phone, setPhone] = useState("");
  const [description, setDescription] = useState("");
  const [logoUrl, setLogoUrl] = useState("");
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [logoPreviewFailed, setLogoPreviewFailed] = useState(false);
  const [logoInputType, setLogoInputType] = useState<"upload" | "url">("upload");
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const logoFileRef = useRef<HTMLInputElement>(null);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // i18n & Theme state
  const [lang, setLang] = useState<"ar" | "en">("ar");
  const [theme, setTheme] = useState<"dark" | "light">("light");

  useEffect(() => {
    const savedLang = (localStorage.getItem("t2h_company_lang") as "ar" | "en") || "ar";
    const savedTheme = (localStorage.getItem("t2h_company_theme") as "dark" | "light") || "light";
    setLang(savedLang);
    setTheme(savedTheme);
    document.documentElement.dir = savedLang === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = savedLang;
    if (savedTheme === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }

    const params = new URLSearchParams(window.location.search);
    const errParam = params.get("error");
    if (errParam === "unauthorized" || errParam === "unauthorized_role") {
      setError(
        savedLang === "ar"
          ? "غير مصرح لهذا الحساب بالوصول إلى تلك البوابة. يرجى تسجيل الدخول بحساب مناسب."
          : "Your account is not authorized for that portal. Please sign in with an authorized account."
      );
    }
  }, []);

  const toggleLanguage = () => {
    const next = lang === "ar" ? "en" : "ar";
    setLang(next);
    localStorage.setItem("t2h_company_lang", next);
    document.documentElement.dir = next === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = next;
  };

  const toggleTheme = () => {
    const next = theme === "dark" ? "light" : "dark";
    setTheme(next);
    localStorage.setItem("t2h_company_theme", next);
    if (next === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  };

  const isRTL = lang === "ar";
  const ArrowIcon = isRTL ? ArrowLeft : ArrowRight;

  const handleLogoFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;

    if (!isAllowedRasterImage(file)) {
      setError(lang === "ar" ? "يرجى اختيار ملف صورة صالح (PNG, JPG, WebP, GIF فقط)." : "Please select a valid raster image (PNG, JPG, WebP, or GIF).");
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      setError(lang === "ar" ? "الحد الأقصى لحجم الشعار هو 10 ميجابايت." : "Logo image must be under 10 MB.");
      return;
    }

    setUploadingLogo(true);
    setError(null);
    setLogoPreviewFailed(false);
    setLogoFile(file);

    // Generate instant local preview; uploaded to Firebase Storage after account creation
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") {
        setLogoUrl(reader.result);
      }
      setUploadingLogo(false);
    };
    reader.onerror = () => {
      console.error("Failed to process logo file.");
      setError(lang === "ar" ? "تعذر قراءة ملف الصورة." : "Failed to read image file.");
      setUploadingLogo(false);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      if (mode === "register") {
        if (!companyName.trim()) {
          throw new Error(lang === "ar" ? "يرجى إدخال اسم الشركة." : "Please enter your company name.");
        }
        if (!isValidEmailAddress(email)) {
          throw new Error(
            lang === "ar"
              ? "يرجى إدخال عنوان بريد إلكتروني صحيح للتحقق والتفعيل (مثال: hr@company.com)."
              : "Please enter a valid work email address for verification (e.g. hr@company.com)."
          );
        }
        if (password.length < 6) {
          throw new Error(lang === "ar" ? "يجب أن تكون كلمة المرور 6 خانات على الأقل." : "Password must be at least 6 characters.");
        }
        if (password !== confirmPassword) {
          throw new Error(lang === "ar" ? "كلمتا المرور غير متطابقتين." : "Passwords do not match.");
        }

        const safeWebsite = website.trim() ? sanitizeExternalUrl(website) : "";
        if (website.trim() && !safeWebsite) {
          throw new Error(lang === "ar" ? "رابط الموقع الإلكتروني غير صالح." : "Please enter a valid http(s) website URL.");
        }

        const safeLogoInput =
          logoInputType === "url" && logoUrl.trim() ? sanitizeImageUrl(logoUrl) : "";
        if (logoInputType === "url" && logoUrl.trim() && safeLogoInput === null) {
          throw new Error(lang === "ar" ? "رابط الشعار غير صالح." : "Please enter a valid image URL.");
        }

        const user = await registerCompanyPortalUser({
          companyName: companyName.trim(),
          email: email.trim(),
          password,
          industry: industry.trim(),
          city: city.trim(),
          country: country.trim(),
          website: safeWebsite || "",
          size: size.trim(),
          phone: phone.trim(),
          description: description.trim(),
          logoUrl: logoInputType === "url" ? safeLogoInput || "" : (logoUrl.length < 300_000 ? logoUrl : ""),
          logoFile: logoInputType === "upload" ? logoFile : null,
        });

        // Notify layout listeners
        if (typeof window !== "undefined") {
          window.dispatchEvent(new Event("company-profile-updated"));
        }

        setSuccessMessage(
          lang === "ar"
            ? `تم إنشاء حساب الشركة (${user.companyName}) وإرسال رابط تفعيل إلى ${user.email || email.trim()}. يرجى تأكيد بريدك الإلكتروني للمتابعة.`
            : `Company account (${user.companyName}) created! A verification link has been sent to ${user.email || email.trim()}.`
        );
        setTimeout(() => {
          router.push(user.redirectUrl);
        }, 1200);
        return;
      }

      // Login Mode
      const user = await signInPortalUser(email, password);
      if (user.role === "COMPANY") {
        setSuccessMessage(
          lang === "ar"
            ? `مرحباً بك، تم تسجيل الدخول بنجاح كشركة (${user.companyName || ""}). جاري الانتقال...`
            : `Welcome back (${user.companyName || "Employer"}). Redirecting...`
        );
      } else {
        setSuccessMessage(
          lang === "ar"
            ? "تم تسجيل دخول المشرف الإداري بنجاح. جاري الانتقال..."
            : "Admin authenticated. Redirecting..."
        );
      }
      setTimeout(() => {
        router.push(user.redirectUrl);
      }, 700);
    } catch (err: any) {
      setError(
        err.message ||
          (lang === "ar"
            ? "فشل تنفيذ العملية. يرجى التحقق من البيانات المدخلة."
            : "Authentication failed. Please verify credentials.")
      );
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div
      dir={isRTL ? "rtl" : "ltr"}
      className="min-h-screen relative flex items-center justify-center p-4 sm:p-6 lg:p-8 bg-slate-50 dark:bg-[#090d16] text-slate-900 dark:text-slate-100 font-sans transition-colors duration-200"
    >
      {/* Background Decorative Accents */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 right-0 w-[500px] h-[500px] bg-indigo-500/10 dark:bg-indigo-600/15 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 left-0 w-[500px] h-[500px] bg-sky-500/10 dark:bg-sky-600/15 rounded-full blur-3xl" />
      </div>

      {/* Floating Top Controls: Brand, Language, Theme */}
      <header className="absolute top-4 left-4 right-4 sm:top-6 sm:left-8 sm:right-8 z-30 flex items-center justify-between pointer-events-auto">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 via-indigo-500 to-sky-500 text-white flex items-center justify-center shadow-md shadow-indigo-500/20 font-black text-sm">
            T2H
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-base font-extrabold tracking-tight text-slate-900 dark:text-white">
                Test<span className="text-indigo-600 dark:text-indigo-400">2</span>Hire
              </span>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-50 dark:bg-indigo-500/20 text-indigo-600 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-500/30">
                Enterprise
              </span>
            </div>
            <p className="text-[11px] text-slate-500 dark:text-slate-400 hidden sm:block">
              {lang === "ar" ? "بوابة توظيف واختبار الكفاءات الذكية" : "Enterprise Talent & Assessment Cloud"}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 sm:gap-3">
          <button
            onClick={toggleLanguage}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-700 shadow-sm text-xs font-semibold transition-colors cursor-pointer"
          >
            <Globe className="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400" />
            <span>{lang === "ar" ? "English" : "العربية"}</span>
          </button>

          <button
            onClick={toggleTheme}
            className="p-2 rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-700 shadow-sm transition-colors cursor-pointer"
            aria-label="Toggle Theme"
            title={theme === "dark" ? "Switch to Light Mode" : "Switch to Dark Mode"}
          >
            {theme === "dark" ? (
              <Sun className="w-4 h-4 text-amber-400" />
            ) : (
              <Moon className="w-4 h-4 text-indigo-600" />
            )}
          </button>
        </div>
      </header>

      {/* Main Container */}
      <main className="relative z-20 w-full max-w-5xl my-auto pt-20 pb-8 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        {/* Left Side: Brand Narrative (Desktop) */}
        <section className="hidden lg:flex lg:col-span-5 flex-col justify-center text-slate-900 dark:text-white space-y-6 pe-4 sticky top-24">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-indigo-50 dark:bg-indigo-500/15 border border-indigo-200 dark:border-indigo-400/30 text-indigo-600 dark:text-indigo-300 text-xs font-semibold w-fit">
            <Sparkles className="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-300" />
            <span>{lang === "ar" ? "منصة توظيف مبنية للمحترفين" : "Built for Talent Acquisition Teams"}</span>
          </div>

          <h1 className="text-3xl font-extrabold tracking-tight leading-snug">
            {lang === "ar" ? (
              <>
                إدارة التوظيف والاختبارات <br />
                <span className="text-indigo-600 dark:text-indigo-400">
                  بسرعة ودقة فائقة
                </span>
              </>
            ) : (
              <>
                Empower Your Hiring <br />
                <span className="text-indigo-600 dark:text-indigo-400">
                  With Precision & Speed
                </span>
              </>
            )}
          </h1>

          <p className="text-slate-600 dark:text-slate-400 text-sm leading-relaxed">
            {lang === "ar"
              ? "انشر الشواغر، صمم اختبارات تقنية محكمة، قابل أفضل المرشحين، وتابع مسارات التوظيف في منصة متكاملة وسلسة."
              : "Publish vacancies, configure proctored technical exams, interview verified applicants, and streamline candidate pipelines."}
          </p>

          <div className="space-y-3 pt-2">
            <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-start gap-3">
              <div className="p-2 rounded-xl bg-indigo-50 dark:bg-indigo-500/20 text-indigo-600 dark:text-indigo-400">
                <BrainCircuit className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-xs font-bold text-slate-900 dark:text-white">
                  {lang === "ar" ? "اختبارات وتقييمات مؤتمتة" : "Automated Technical Assessments"}
                </h3>
                <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
                  {lang === "ar" ? "تصحيح آلي وتقارير فورية لنتائج المرشحين" : "Instant auto-grading and scorecards"}
                </p>
              </div>
            </div>

            <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900/60 border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-start gap-3">
              <div className="p-2 rounded-xl bg-emerald-50 dark:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400">
                <ShieldCheck className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-xs font-bold text-slate-900 dark:text-white">
                  {lang === "ar" ? "تزامن لحظي مع تطبيق الهاتف" : "Real-time Mobile Synchronization"}
                </h3>
                <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
                  {lang === "ar" ? "وصول فوري للوظائف والتقديم من المرشحين" : "Seamless candidate application flow"}
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* Right Side: Auth Form Card */}
        <div className={`w-full mx-auto ${mode === "register" ? "lg:col-span-7 max-w-xl" : "lg:col-span-7 max-w-md"}`}>
          <div className="relative rounded-3xl bg-white dark:bg-slate-900 border border-slate-200/90 dark:border-slate-800 p-6 sm:p-8 shadow-xl transition-all">
            {/* Header */}
            <div className="flex flex-col items-center mb-6 text-center">
              <div className="w-12 h-12 rounded-2xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 border border-indigo-200/60 dark:border-indigo-800/60 flex items-center justify-center mb-3 shadow-sm">
                <Building2 className="w-6 h-6" />
              </div>
              <h2 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white tracking-tight">
                {mode === "login"
                  ? lang === "ar"
                    ? "تسجيل دخول الشركات"
                    : "Employer Sign In"
                  : lang === "ar"
                  ? "تسجيل حساب شركة جديد"
                  : "Register Employer Account"}
              </h2>
              <p className="text-slate-500 dark:text-slate-400 text-xs mt-1">
                {mode === "login"
                  ? lang === "ar"
                    ? "أدخل بيانات حسابك للوصول إلى لوحة التحكم"
                    : "Access your recruitment dashboard & exams"
                  : lang === "ar"
                  ? "أدخل تفاصيل شركتك وشعارها للبدء بالتوظيف"
                  : "Complete your corporate profile and logo to start hiring"}
              </p>
            </div>

            {/* Mode Switcher */}
            <div className="grid grid-cols-2 gap-1 p-1 bg-slate-100 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-2xl mb-6">
              <button
                type="button"
                onClick={() => {
                  setMode("login");
                  setError(null);
                }}
                className={`py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${
                  mode === "login"
                    ? "bg-white dark:bg-slate-800 text-slate-900 dark:text-white shadow-sm"
                    : "text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white"
                }`}
              >
                {lang === "ar" ? "تسجيل الدخول" : "Sign In"}
              </button>
              <button
                type="button"
                onClick={() => {
                  setMode("register");
                  setError(null);
                }}
                className={`py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${
                  mode === "register"
                    ? "bg-indigo-600 text-white shadow-sm"
                    : "text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white"
                }`}
              >
                {lang === "ar" ? "تسجيل شركة جديدة" : "Register Company"}
              </button>
            </div>

            {/* Alerts */}
            {error && (
              <div className="mb-5 p-3.5 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 rounded-2xl flex items-start gap-2.5 text-rose-700 dark:text-rose-300 text-xs leading-relaxed animate-in fade-in">
                <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-rose-600 dark:text-rose-400" />
                <span>{error}</span>
              </div>
            )}

            {successMessage ? (
              <div className="p-6 bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 rounded-2xl text-emerald-700 dark:text-emerald-300 text-xs text-center leading-relaxed font-medium animate-in fade-in flex flex-col items-center gap-2">
                <CheckCircle2 className="w-6 h-6 text-emerald-600 dark:text-emerald-400 animate-bounce" />
                <span>{successMessage}</span>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-4">
                {mode === "register" && (
                  <>
                    {/* Company Logo Upload & Preview Card */}
                    <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-950/50 border border-slate-200 dark:border-slate-800 space-y-3">
                      <div className="flex items-center justify-between">
                        <label className="text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300">
                          {lang === "ar" ? "شعار الشركة (Company Logo)" : "Company Logo"}
                        </label>
                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => setLogoInputType("upload")}
                            className={`px-2 py-0.5 text-[10px] rounded-md font-semibold transition-colors cursor-pointer ${
                              logoInputType === "upload"
                                ? "bg-indigo-600 text-white"
                                : "text-slate-500 hover:text-slate-800 dark:text-slate-400"
                            }`}
                          >
                            {lang === "ar" ? "رفع ملف" : "File"}
                          </button>
                          <button
                            type="button"
                            onClick={() => setLogoInputType("url")}
                            className={`px-2 py-0.5 text-[10px] rounded-md font-semibold transition-colors cursor-pointer ${
                              logoInputType === "url"
                                ? "bg-indigo-600 text-white"
                                : "text-slate-500 hover:text-slate-800 dark:text-slate-400"
                            }`}
                          >
                            {lang === "ar" ? "رابط مباشر" : "URL"}
                          </button>
                        </div>
                      </div>

                      <div className="flex items-center gap-4">
                        {/* Logo Preview */}
                        <div className="relative w-16 h-16 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 flex items-center justify-center overflow-hidden flex-shrink-0 shadow-sm">
                          {logoUrl && !logoPreviewFailed ? (
                            <img
                              src={logoUrl}
                              alt="Logo Preview"
                              className="w-full h-full object-cover"
                              onError={() => setLogoPreviewFailed(true)}
                            />
                          ) : (
                            <div className="text-center p-1">
                              <ImageIcon className="w-5 h-5 mx-auto text-slate-400" />
                              <span className="text-[9px] text-slate-400 block mt-0.5 leading-tight">
                                {lang === "ar" ? "معاينة" : "Preview"}
                              </span>
                            </div>
                          )}
                          {uploadingLogo && (
                            <div className="absolute inset-0 bg-black/60 flex items-center justify-center text-white">
                              <Loader2 className="w-4 h-4 animate-spin" />
                            </div>
                          )}
                        </div>

                        <div className="flex-1 space-y-1.5">
                          {logoInputType === "upload" ? (
                            <>
                              <input
                                ref={logoFileRef}
                                type="file"
                                accept="image/jpeg,image/png,image/webp,image/gif"
                                onChange={handleLogoFileChange}
                                className="hidden"
                              />
                              <button
                                type="button"
                                onClick={() => logoFileRef.current?.click()}
                                disabled={uploadingLogo}
                                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-700 shadow-sm transition-colors cursor-pointer"
                              >
                                <Upload className="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400" />
                                <span>{logoUrl ? (lang === "ar" ? "تغيير الصورة" : "Change Image") : (lang === "ar" ? "اختر صورة الشعار" : "Select Logo Image")}</span>
                              </button>
                              <p className="text-[10px] text-slate-500 dark:text-slate-400">
                                {lang === "ar" ? "صيغ PNG, JPG, WebP بحجم مناسب" : "Supports PNG, JPG, WebP"}
                              </p>
                            </>
                          ) : (
                            <div className="flex items-center gap-2">
                              <input
                                type="url"
                                value={logoUrl}
                                onChange={(e) => {
                                  setLogoUrl(e.target.value);
                                  setLogoFile(null);
                                  setLogoPreviewFailed(false);
                                }}
                                placeholder="https://example.com/logo.png"
                                className="w-full px-3 py-1.5 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                              />
                            </div>
                          )}
                          {(logoUrl || logoFile) && (
                            <button
                              type="button"
                              onClick={() => {
                                setLogoUrl("");
                                setLogoFile(null);
                                setLogoPreviewFailed(false);
                                if (logoFileRef.current) logoFileRef.current.value = "";
                              }}
                              className="text-[10px] text-rose-600 dark:text-rose-400 hover:underline cursor-pointer block"
                            >
                              {lang === "ar" ? "إزالة الشعار" : "Remove"}
                            </button>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Company Name */}
                    <div>
                      <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                        {lang === "ar" ? "اسم الشركة / المؤسسة *" : "Company Name *"}
                      </label>
                      <input
                        type="text"
                        required
                        value={companyName}
                        onChange={(e) => setCompanyName(e.target.value)}
                        placeholder={lang === "ar" ? "مثال: شركة الحلول الذكية للتكنولوجيا" : "e.g. Apex Global Technologies"}
                        className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 font-semibold"
                      />
                    </div>

                    {/* Industry & Size */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                          {lang === "ar" ? "مجال العمل / القطاع" : "Industry"}
                        </label>
                        <input
                          type="text"
                          value={industry}
                          onChange={(e) => setIndustry(e.target.value)}
                          placeholder="Technology, Healthcare, Finance..."
                          className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>

                      <div>
                        <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                          {lang === "ar" ? "حجم الشركة" : "Company Size"}
                        </label>
                        <select
                          value={size}
                          onChange={(e) => setSize(e.target.value)}
                          className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 cursor-pointer"
                        >
                          <option value="1-10">1-10 {lang === "ar" ? "موظف (ناشئة)" : "employees (Startup)"}</option>
                          <option value="11-50">11-50 {lang === "ar" ? "موظف (صغيرة)" : "employees (Small)"}</option>
                          <option value="51-200">51-200 {lang === "ar" ? "موظف (متوسطة)" : "employees (Medium)"}</option>
                          <option value="201-500">201-500 {lang === "ar" ? "موظف (كبيرة)" : "employees (Large)"}</option>
                          <option value="500+">500+ {lang === "ar" ? "موظف (مؤسسة دولية)" : "employees (Enterprise)"}</option>
                        </select>
                      </div>
                    </div>

                    {/* Location: Country & City */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                          {lang === "ar" ? "الدولة" : "Country"}
                        </label>
                        <input
                          type="text"
                          value={country}
                          onChange={(e) => setCountry(e.target.value)}
                          placeholder="Jordan, Saudi Arabia, UAE..."
                          className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>

                      <div>
                        <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                          {lang === "ar" ? "المدينة" : "City"}
                        </label>
                        <input
                          type="text"
                          value={city}
                          onChange={(e) => setCity(e.target.value)}
                          placeholder="Amman, Riyadh, Dubai..."
                          className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>
                    </div>

                    {/* Website & Phone */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                          {lang === "ar" ? "الموقع الإلكتروني" : "Corporate Website"}
                        </label>
                        <input
                          type="url"
                          value={website}
                          onChange={(e) => setWebsite(e.target.value)}
                          placeholder="https://company.com"
                          className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>

                      <div>
                        <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                          {lang === "ar" ? "رقم الهاتف للتواصل" : "Contact Phone"}
                        </label>
                        <input
                          type="tel"
                          value={phone}
                          onChange={(e) => setPhone(e.target.value)}
                          placeholder="+962 7 9000 0000"
                          className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>
                    </div>

                    {/* Bio / Description */}
                    <div>
                      <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                        {lang === "ar" ? "نبذة تعريفية عن الشركة" : "Company Overview / Bio"}
                      </label>
                      <textarea
                        rows={2}
                        value={description}
                        onChange={(e) => setDescription(e.target.value)}
                        placeholder={lang === "ar" ? "اكتب نبذة مختصرة عن نشاط الشركة ورؤيتها..." : "Brief overview of company missions and products..."}
                        className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>
                  </>
                )}

                {/* Email Address */}
                <div>
                  <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                    {lang === "ar" ? "البريد الإلكتروني للعمل *" : "Work Email Address *"}
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="hr@company.com"
                    className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-indigo-500"
                  />
                  {mode === "register" && (
                    <p className="mt-1 text-[10px] text-slate-500 dark:text-slate-400">
                      {lang === "ar"
                        ? "سيتم إرسال رابط تحقق وتفعيل إجباري لهذا البريد الإلكتروني قبل تفعيل حساب الشركة."
                        : "A mandatory verification link will be sent to this address before enabling company portal features."}
                    </p>
                  )}
                </div>

                {/* Password & Confirm Password */}
                <div className={mode === "register" ? "grid grid-cols-1 sm:grid-cols-2 gap-3" : "space-y-1"}>
                  <div>
                    <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                      {lang === "ar" ? "كلمة المرور *" : "Password *"}
                    </label>
                    <div className="relative">
                      <input
                        type={showPassword ? "text" : "password"}
                        required
                        minLength={6}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="••••••••••••"
                        className="w-full ps-3.5 pe-9 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-indigo-500"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        aria-label={showPassword ? "Hide password" : "Show password"}
                        className="absolute end-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
                      >
                        {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                      </button>
                    </div>
                  </div>

                  {mode === "register" && (
                    <div>
                      <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-300 mb-1">
                        {lang === "ar" ? "تأكيد كلمة المرور *" : "Confirm Password *"}
                      </label>
                      <div className="relative">
                        <input
                          type={showPassword ? "text" : "password"}
                          required
                          minLength={6}
                          value={confirmPassword}
                          onChange={(e) => setConfirmPassword(e.target.value)}
                          placeholder="••••••••••••"
                          className="w-full ps-3.5 pe-9 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-indigo-500"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword(!showPassword)}
                          aria-label={showPassword ? "Hide password" : "Show password"}
                          className="absolute end-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
                        >
                          {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                        </button>
                      </div>
                    </div>
                  )}
                </div>

                {/* Submit Button */}
                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full py-3 mt-4 bg-indigo-600 hover:bg-indigo-500 active:bg-indigo-700 disabled:opacity-50 text-white font-bold rounded-xl transition-all flex items-center justify-center gap-2 text-xs shadow-md shadow-indigo-600/25 hover:scale-[1.01] active:scale-[0.99] cursor-pointer"
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>
                        {lang === "ar"
                          ? "جاري المعالجة والتحقق..."
                          : mode === "register"
                          ? "Registering Company..."
                          : "Authenticating..."}
                      </span>
                    </>
                  ) : (
                    <>
                      <span>
                        {mode === "register"
                          ? lang === "ar"
                            ? "إنشاء حساب الشركة والدخول إلى البوابة"
                            : "Create Company Account & Enter"
                          : lang === "ar"
                          ? "تسجيل الدخول إلى البوابة"
                          : "Sign In to Portal"}
                      </span>
                      <ArrowIcon className="w-4 h-4" />
                    </>
                  )}
                </button>
              </form>
            )}

            {/* Footer Notice */}
            <div className="mt-6 pt-5 border-t border-slate-100 dark:border-slate-800 text-center space-y-1">
              <p className="text-[11px] text-slate-500 dark:text-slate-400">
                {lang === "ar"
                  ? "الباحثون عن عمل: يرجى التقديم عبر تطبيق Test2Hire للهاتف."
                  : "Job Seekers: Please apply via the Test2Hire Mobile App."}
              </p>
              <p className="text-[10px] text-slate-400 dark:text-slate-500">
                Test2Hire Enterprise Portal • Protected by Firebase Auth
              </p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
