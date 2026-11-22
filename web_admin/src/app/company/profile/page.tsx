"use client";

import React, { useEffect, useState, useRef } from "react";
import { auth, storage } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { useCompany } from "@/lib/i18n";
import {
  isAllowedRasterImage,
  sanitizeExternalUrl,
  sanitizeImageUrl,
} from "@/lib/formatters";
import {
  getCompanyProfile,
  updateCompanyProfile,
} from "@/lib/company-portal-service";
import {
  CheckCircle2,
  Clock,
  Save,
  Loader2,
  Building2,
  Upload,
  Image as ImageIcon,
  Link as LinkIcon,
  Globe,
  MapPin,
  Mail,
  Phone,
  FileText,
  ShieldCheck,
  AlertTriangle,
  XCircle,
  Check,
} from "lucide-react";

export default function CompanyProfilePage() {
  const { t, language } = useCompany();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [logoLoadError, setLogoLoadError] = useState(false);
  const [companyId, setCompanyId] = useState("");

  // Form Fields
  const [name, setName] = useState("");
  const [logoUrl, setLogoUrl] = useState("");
  const [industry, setIndustry] = useState("");
  const [size, setSize] = useState("");
  const [website, setWebsite] = useState("");
  const [description, setDescription] = useState("");
  const [country, setCountry] = useState("");
  const [city, setCity] = useState("");
  const [address, setAddress] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [taxNumber, setTaxNumber] = useState("");
  const [commercialRegister, setCommercialRegister] = useState("");
  const [verificationStatus, setVerificationStatus] = useState("PENDING");

  const [showUrlInput, setShowUrlInput] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [feedback, setFeedback] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const loadProfile = async (uid?: string) => {
    const targetUid = uid || auth.currentUser?.uid;
    if (!targetUid) {
      setLoading(false);
      return;
    }
    try {
      setLoading(true);
      setCompanyId(targetUid);
      const data = await getCompanyProfile(targetUid);
      if (data) {
        const loc = typeof data.location === "object" && data.location !== null ? data.location : null;
        setName(data.name || data.companyName || "");
        setLogoUrl(data.logoUrl || data.logo || "");
        setLogoLoadError(false);
        setIndustry(data.industry || "");
        setSize(data.teamSize || data.size || "11-50");
        setWebsite(data.website || "");
        setDescription(data.description || "");
        setCountry(loc?.country || data.country || "Jordan");
        setCity(loc?.city || data.city || "Amman");
        setAddress(loc?.address || data.address || "");
        setContactEmail(data.contactEmail || auth.currentUser?.email || "");
        setContactPhone(data.contactPhone || "");
        setTaxNumber(data.taxNumber || "");
        setCommercialRegister(data.commercialRegister || "");
        setVerificationStatus((data.verificationStatus || "PENDING").toUpperCase());
      }
    } catch (err) {
      console.error("Failed to load profile:", err);
      setFeedback({ type: "error", text: t("error") });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        loadProfile(user.uid);
      } else {
        setLoading(false);
      }
    });
    return () => unsub();
  }, []);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;

    if (!isAllowedRasterImage(file)) {
      setFeedback({
        type: "error",
        text: language === "ar" ? "يرجى اختيار ملف صورة صالح (PNG, JPG, WebP, GIF فقط)." : "Please select a valid raster image (PNG, JPG, WebP, or GIF).",
      });
      return;
    }

    if (file.size > 10 * 1024 * 1024) {
      setFeedback({
        type: "error",
        text: language === "ar" ? "الحد الأقصى لحجم الشعار 10 ميجابايت." : "Logo file must be smaller than 10MB.",
      });
      return;
    }

    try {
      setUploadingLogo(true);
      if (companyId && storage) {
        try {
          const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
          const storageRef = ref(storage, `companies/${companyId}/logo/${Date.now()}_${safeName}`);
          await uploadBytes(storageRef, file, { contentType: file.type });
          const downloadUrl = await getDownloadURL(storageRef);
          setLogoUrl(downloadUrl);
          setLogoLoadError(false);
          setFeedback({
            type: "success",
            text: language === "ar" ? "تم رفع الشعار بنجاح! لا تنس حفظ التغييرات." : "Logo uploaded! Remember to save changes.",
          });
          return;
        } catch (storageErr) {
          console.warn("Storage upload failed, checking local fallback:", storageErr);
        }
      }

      if (file.size > 700 * 1024) {
        setFeedback({
          type: "error",
          text:
            language === "ar"
              ? "تعذر الرفع إلى التخزين السحابي، والصورة كبيرة جداً للحفظ المباشر (اختر صورة أصغر من 700 كيلوبايت أو استخدم رابطاً مباشراً)."
              : "Cloud storage upload failed and image exceeds 700KB inline limit. Please use a smaller file or a direct URL.",
        });
        return;
      }

      const dataUrl = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
          if (typeof reader.result === "string") resolve(reader.result);
          else reject(new Error("Could not read image data."));
        };
        reader.onerror = () => reject(reader.error || new Error("Failed to read file."));
        reader.readAsDataURL(file);
      });

      setLogoUrl(dataUrl);
      setLogoLoadError(false);
      setFeedback({
        type: "success",
        text: language === "ar" ? "تم اختيار الشعار بنجاح! لا تنس حفظ التغييرات." : "Logo selected! Remember to save changes.",
      });
    } catch (err: any) {
      console.error("Error processing logo file:", err);
      setFeedback({
        type: "error",
        text: err.message || (language === "ar" ? "فشل معالجة صورة الشعار." : "Failed to process logo image."),
      });
    } finally {
      setUploadingLogo(false);
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!companyId) return;

    if (!name.trim() || !industry.trim()) {
      setFeedback({
        type: "error",
        text:
          language === "ar"
            ? "يرجى إدخال اسم الشركة والقطاع قبل الحفظ."
            : "Please enter company name and industry before saving.",
      });
      return;
    }

    const cleanWebsite = website.trim() ? sanitizeExternalUrl(website) : "";
    if (website.trim() && !cleanWebsite) {
      setFeedback({
        type: "error",
        text:
          language === "ar"
            ? "رابط الموقع الإلكتروني غير صالح (يجب أن يبدأ بـ http أو https)."
            : "Please enter a valid http(s) website URL.",
      });
      return;
    }

    const cleanLogoUrl = logoUrl.trim() ? sanitizeImageUrl(logoUrl) : "";
    if (logoUrl.trim() && cleanLogoUrl === null) {
      setFeedback({
        type: "error",
        text:
          language === "ar"
            ? "رابط الشعار غير صالح أو بصيغة غير مدعومة."
            : "Please provide a valid https(s) or raster image URL for the logo.",
      });
      return;
    }

    try {
      setSaving(true);
      await updateCompanyProfile(companyId, {
        name: name.trim(),
        companyName: name.trim(),
        logoUrl: cleanLogoUrl || "",
        industry: industry.trim(),
        size: size.trim() || "11-50",
        teamSize: size.trim() || "11-50",
        website: cleanWebsite || "",
        description: description.trim(),
        country: country.trim(),
        city: city.trim(),
        address: address.trim(),
        contactEmail: contactEmail.trim(),
        contactPhone: contactPhone.trim(),
        taxNumber: taxNumber.trim(),
        commercialRegister: commercialRegister.trim(),
      });

      window.dispatchEvent(new Event("company-profile-updated"));
      setFeedback({ type: "success", text: t("success") });
    } catch (err: any) {
      console.error("Failed to update profile:", err);
      setFeedback({ type: "error", text: err.message || t("error") });
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="py-24 flex flex-col items-center justify-center gap-3">
        <div className="w-10 h-10 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{t("loading")}</p>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">{t("profileTitle")}</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{t("profileSubtitle")}</p>
        </div>
      </div>

      {/* Verification Status Banner */}
      <div
        className={`p-4 rounded-2xl border flex items-center justify-between gap-3 ${
          verificationStatus === "APPROVED"
            ? "bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800 text-emerald-900 dark:text-emerald-200"
            : verificationStatus === "REJECTED" || verificationStatus === "SUSPENDED"
            ? "bg-rose-50 dark:bg-rose-950/40 border-rose-200 dark:border-rose-800 text-rose-900 dark:text-rose-200"
            : "bg-amber-50 dark:bg-amber-950/40 border-amber-200 dark:border-amber-800 text-amber-900 dark:text-amber-200"
        }`}
      >
        <div className="flex items-center gap-3">
          <div
            className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
              verificationStatus === "APPROVED"
                ? "bg-emerald-100 dark:bg-emerald-900/60 text-emerald-600 dark:text-emerald-400"
                : verificationStatus === "REJECTED" || verificationStatus === "SUSPENDED"
                ? "bg-rose-100 dark:bg-rose-900/60 text-rose-600 dark:text-rose-400"
                : "bg-amber-100 dark:bg-amber-900/60 text-amber-600 dark:text-amber-400"
            }`}
          >
            {verificationStatus === "APPROVED" ? (
              <CheckCircle2 className="w-6 h-6" />
            ) : verificationStatus === "REJECTED" || verificationStatus === "SUSPENDED" ? (
              <XCircle className="w-6 h-6" />
            ) : (
              <Clock className="w-6 h-6" />
            )}
          </div>
          <div>
            <h3 className="font-bold text-sm">
              {verificationStatus === "APPROVED"
                ? t("verifiedTitle")
                : verificationStatus === "REJECTED"
                ? language === "ar"
                  ? "تم رفض توثيق الحساب"
                  : "Verification Rejected"
                : verificationStatus === "SUSPENDED"
                ? language === "ar"
                  ? "تم إيقاف حساب الشركة مؤقتاً"
                  : "Company Account Suspended"
                : t("pendingTitle")}
            </h3>
            <p className="text-xs opacity-80 mt-0.5">
              {verificationStatus === "APPROVED"
                ? t("verifiedDesc")
                : verificationStatus === "REJECTED"
                ? language === "ar"
                  ? "يرجى تحديث بيانات السجل التجاري والتواصل مع إدارة المنصة."
                  : "Please update your commercial details and contact platform support."
                : verificationStatus === "SUSPENDED"
                ? language === "ar"
                  ? "تم تعليق صلاحيات النشر حالياً. يرجى التواصل مع الإدارة."
                  : "Publishing is currently paused. Please contact platform administrators."
                : t("pendingDesc")}
            </p>
          </div>
        </div>

        <span className="text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wider bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-200 shadow-sm border border-slate-200 dark:border-slate-700 shrink-0">
          {verificationStatus}
        </span>
      </div>

      {/* Action Notification */}
      {feedback && (
        <div
          className={`p-4 rounded-xl text-xs sm:text-sm font-medium border flex items-center justify-between ${
            feedback.type === "success"
              ? "bg-emerald-50 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800"
              : "bg-rose-50 dark:bg-rose-950/60 text-rose-800 dark:text-rose-300 border-rose-200 dark:border-rose-800"
          }`}
        >
          <span>{feedback.text}</span>
          <button type="button" onClick={() => setFeedback(null)} className="text-xs font-bold uppercase hover:underline">
            {t("close")}
          </button>
        </div>
      )}

      {/* Profile Form */}
      <form
        onSubmit={handleSave}
        className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm p-6 sm:p-8 space-y-6"
      >
        {/* Company Brand Card: Logo + Identity */}
        <div className="p-5 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/80 dark:border-slate-700/70 flex flex-col sm:flex-row items-center gap-5">
          <div className="relative group">
            {logoUrl && !logoLoadError ? (
              <div className="w-20 h-20 rounded-2xl overflow-hidden border-2 border-indigo-500/40 bg-white shadow-md flex items-center justify-center">
                <img
                  src={logoUrl}
                  alt={name || "Company Logo"}
                  loading="lazy"
                  decoding="async"
                  className="w-full h-full object-cover"
                  onError={() => setLogoLoadError(true)}
                />
              </div>
            ) : (
              <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-indigo-600 via-indigo-500 to-sky-500 text-white flex items-center justify-center font-black text-2xl shadow-md">
                {name ? name.slice(0, 2).toUpperCase() : <Building2 className="w-9 h-9" />}
              </div>
            )}
            {uploadingLogo && (
              <div className="absolute inset-0 bg-black/50 rounded-2xl flex items-center justify-center text-white">
                <Loader2 className="w-6 h-6 animate-spin" />
              </div>
            )}
          </div>

          <div className="flex-1 text-center sm:text-start space-y-2">
            <div>
              <h2 className="text-sm font-bold text-slate-900 dark:text-white">
                {t("companyLogoLabel")}
              </h2>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                {t("companyLogoHint")}
              </p>
            </div>

            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2 pt-1">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp,image/gif"
                onChange={handleFileUpload}
                className="hidden"
              />
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={uploadingLogo}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm transition-colors cursor-pointer"
              >
                <Upload className="w-3.5 h-3.5" />
                <span>{logoUrl ? t("changeLogoBtn") : t("uploadLogoBtn")}</span>
              </button>

              <button
                type="button"
                onClick={() => setShowUrlInput(!showUrlInput)}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors cursor-pointer"
              >
                <LinkIcon className="w-3.5 h-3.5" />
                <span>{language === "ar" ? "رابط مباشر" : "URL Link"}</span>
              </button>

              {logoUrl && (
                <button
                  type="button"
                  onClick={() => setLogoUrl("")}
                  className="px-2.5 py-1.5 text-xs text-rose-600 dark:text-rose-400 hover:underline cursor-pointer"
                >
                  {language === "ar" ? "إزالة الشعار" : "Remove"}
                </button>
              )}
            </div>

            {showUrlInput && (
              <div className="pt-2 animate-in fade-in">
                <input
                  type="url"
                  value={logoUrl}
                  onChange={(e) => {
                    setLogoUrl(e.target.value);
                    setLogoLoadError(false);
                  }}
                  placeholder="https://example.com/logo.png"
                  className="w-full px-3 py-1.5 text-xs border border-slate-300 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                />
              </div>
            )}
          </div>
        </div>

        {/* Basic Info */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("companyNameLabel")}</label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 font-semibold"
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("industryLabel")}</label>
            <input
              type="text"
              required
              value={industry}
              onChange={(e) => setIndustry(e.target.value)}
              placeholder="e.g. Information Technology & AI"
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("companySizeLabel")}</label>
            <select
              value={size}
              onChange={(e) => setSize(e.target.value)}
              className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            >
              <option value="1-10">{language === "ar" ? "1-10 موظفين (ناشئة)" : "1-10 employees (Startup)"}</option>
              <option value="11-50">{language === "ar" ? "11-50 موظفاً (صغيرة)" : "11-50 employees (Small)"}</option>
              <option value="51-200">{language === "ar" ? "51-200 موظف (متوسطة)" : "51-200 employees (Medium)"}</option>
              <option value="201-500">{language === "ar" ? "201-500 موظف (كبيرة نسبياً)" : "201-500 employees (Mid-Market)"}</option>
              <option value="500+">{language === "ar" ? "أكثر من 500 موظف (مؤسسة كبرى)" : "500+ employees (Enterprise)"}</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("websiteLabel")}</label>
            <input
              type="url"
              value={website}
              onChange={(e) => setWebsite(e.target.value)}
              placeholder="https://company.com"
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div>
          <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("aboutCompanyLabel")}</label>
          <textarea
            rows={4}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder={
              language === "ar"
                ? "اكتب نبذة مختصرة عن ثقافة الشركة ورسالتها وأبرز إنجازاتها..."
                : "Write a brief overview about your company culture, mission, and achievements..."
            }
            className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("countryLabel")}</label>
            <input
              type="text"
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("cityLabel")}</label>
            <input
              type="text"
              value={city}
              onChange={(e) => setCity(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("addressLabel")}</label>
            <input
              type="text"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("contactEmailLabel")}</label>
            <input
              type="email"
              value={contactEmail}
              onChange={(e) => setContactEmail(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("contactPhoneLabel")}</label>
            <input
              type="tel"
              value={contactPhone}
              onChange={(e) => setContactPhone(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("taxNumberLabel")}</label>
            <input
              type="text"
              value={taxNumber}
              onChange={(e) => setTaxNumber(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("crNumberLabel")}</label>
            <input
              type="text"
              value={commercialRegister}
              onChange={(e) => setCommercialRegister(e.target.value)}
              className="w-full px-3.5 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="pt-4 flex justify-end border-t border-slate-100 dark:border-slate-800">
          <button
            type="submit"
            disabled={saving}
            className="px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 flex items-center gap-2 cursor-pointer transition-transform hover:scale-[1.01]"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            <span>{t("saveProfileBtn")}</span>
          </button>
        </div>
      </form>
    </div>
  );
}
