"use client";

import React, { useEffect, useState } from "react";
import { auth, db } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { useCompany } from "@/lib/i18n";
import { formatTimestamp, sanitizeImageUrl } from "@/lib/formatters";
import {
  collection,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  getDocs,
  onSnapshot,
  query,
  where,
  limit,
  writeBatch,
  serverTimestamp,
  increment,
} from "firebase/firestore";
import {
  MessageSquare,
  ThumbsUp,
  Send,
  Trash2,
  CheckCircle2,
  AlertCircle,
  Sparkles,
  Tag,
  X,
  Loader2,
} from "lucide-react";

interface WebCommunityPost {
  id: string;
  authorId: string;
  authorName: string;
  authorHeadline: string;
  authorRole: string;
  authorAvatarUrl?: string;
  companyId?: string;
  content: string;
  imageUrl?: string;
  tags: string[];
  likedBy: string[];
  likesCount: number;
  commentsCount: number;
  createdAt?: any;
}

interface WebCommunityComment {
  id: string;
  postId: string;
  authorId: string;
  authorName: string;
  authorHeadline: string;
  authorRole: string;
  content: string;
  createdAt?: any;
}

const TOPICS = [
  { value: "Career Advice", labelAr: "نصائح مهنية", labelEn: "Career Advice" },
  { value: "Tech & Engineering", labelAr: "التقنية والهندسة", labelEn: "Tech & Engineering" },
  { value: "Hiring Updates", labelAr: "تحديثات التوظيف", labelEn: "Hiring Updates" },
  { value: "Interview Tips", labelAr: "نصائح المقابلات", labelEn: "Interview Tips" },
];

export default function CompanyCommunityPage() {
  const { t, isRTL, companyInfo } = useCompany();

  const [currentUid, setCurrentUid] = useState<string>("");
  const [posts, setPosts] = useState<WebCommunityPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [newContent, setNewContent] = useState("");
  const [selectedTag, setSelectedTag] = useState("Hiring Updates");
  const [submitting, setSubmitting] = useState(false);
  const [deletingPostId, setDeletingPostId] = useState<string | null>(null);
  const [commentingPostId, setCommentingPostId] = useState<string | null>(null);
  const [brokenAvatars, setBrokenAvatars] = useState<Record<string, boolean>>({});
  const [actionFeedback, setActionFeedback] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const [expandedPostId, setExpandedPostId] = useState<string | null>(null);
  const [commentsByPost, setCommentsByPost] = useState<
    Record<string, WebCommunityComment[]>
  >({});
  const [commentInput, setCommentInput] = useState<Record<string, string>>({});

  const resolvedCompanyName = companyInfo?.name || (isRTL ? "شركة توظيف" : "Hiring Company");
  const resolvedHeadline = companyInfo?.industry
    ? isRTL
      ? `${companyInfo.industry} • شريك توظيف رسمي`
      : `${companyInfo.industry} • Official Hiring Partner`
    : isRTL
    ? "شريك توظيف رسمي"
    : "Official Hiring Partner";

  useEffect(() => {
    const unsubAuth = onAuthStateChanged(auth, (user) => {
      setCurrentUid(user?.uid || "");
    });

    const postsQuery = query(collection(db, "communityPosts"), limit(50));
    const unsubPosts = onSnapshot(
      postsQuery,
      (snap) => {
        const list: WebCommunityPost[] = snap.docs.map((d) => {
          const data = d.data();
          const likedBy = Array.isArray(data.likedBy) ? data.likedBy : [];
          return {
            id: d.id,
            authorId: data.authorId || "",
            authorName: data.authorName || (isRTL ? "عضو" : "Member"),
            authorHeadline: data.authorHeadline || (isRTL ? "محترف" : "Professional"),
            authorRole: data.authorRole || "CANDIDATE",
            authorAvatarUrl: data.authorAvatarUrl,
            companyId: data.companyId,
            content: data.content || "",
            imageUrl: data.imageUrl,
            tags: Array.isArray(data.tags) ? data.tags : [],
            likedBy,
            likesCount:
              typeof data.likesCount === "number"
                ? data.likesCount
                : likedBy.length,
            commentsCount:
              typeof data.commentsCount === "number" ? data.commentsCount : 0,
            createdAt: data.createdAt,
          };
        });

        list.sort((a, b) => {
          const tA = a.createdAt?.seconds ? a.createdAt.seconds * 1000 : 0;
          const tB = b.createdAt?.seconds ? b.createdAt.seconds * 1000 : 0;
          return tB - tA;
        });
        setPosts(list);
        setLoading(false);
      },
      (err) => {
        console.error("Community posts listener error:", err);
        setActionFeedback({ type: "error", text: t("error") });
        setLoading(false);
      }
    );

    return () => {
      unsubAuth();
      unsubPosts();
    };
  }, [isRTL, t]);

  useEffect(() => {
    if (!expandedPostId) return;
    const q = query(
      collection(db, "communityComments"),
      where("postId", "==", expandedPostId),
      limit(50)
    );
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list: WebCommunityComment[] = snap.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            postId: data.postId || expandedPostId,
            authorId: data.authorId || "",
            authorName: data.authorName || "Member",
            authorHeadline: data.authorHeadline || "Professional",
            authorRole: data.authorRole || "CANDIDATE",
            content: data.content || "",
            createdAt: data.createdAt,
          };
        });
        list.sort((a, b) => {
          const tA = a.createdAt?.seconds ? a.createdAt.seconds * 1000 : 0;
          const tB = b.createdAt?.seconds ? b.createdAt.seconds * 1000 : 0;
          return tA - tB;
        });
        setCommentsByPost((prev) => ({ ...prev, [expandedPostId]: list }));
      },
      (err) => {
        console.error("Comments listener error:", err);
        setActionFeedback({ type: "error", text: t("error") });
      }
    );
    return () => unsub();
  }, [expandedPostId, t]);

  const handlePublish = async (e: React.FormEvent) => {
    e.preventDefault();
    const user = auth.currentUser;
    if (!user || !newContent.trim()) return;
    setSubmitting(true);
    setActionFeedback(null);
    try {
      await addDoc(collection(db, "communityPosts"), {
        authorId: user.uid,
        authorName: resolvedCompanyName,
        authorHeadline: resolvedHeadline,
        authorRole: "COMPANY",
        authorAvatarUrl: companyInfo?.logoUrl || null,
        companyId: user.uid,
        content: newContent.trim(),
        tags: [selectedTag],
        likedBy: [],
        likesCount: 0,
        commentsCount: 0,
        createdAt: serverTimestamp(),
      });
      setNewContent("");
      setActionFeedback({
        type: "success",
        text: isRTL ? "تم نشر تحديث الشركة في المجتمع بنجاح!" : "Post published to the community!",
      });
    } catch (err: any) {
      console.error("Failed to publish post:", err);
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setSubmitting(false);
    }
  };

  const handleToggleLike = async (post: WebCommunityPost) => {
    const user = auth.currentUser;
    if (!user) return;
    const isLiked = post.likedBy.includes(user.uid);
    const nextLikedBy = isLiked
      ? post.likedBy.filter((id) => id !== user.uid)
      : [...post.likedBy, user.uid];

    try {
      await updateDoc(doc(db, "communityPosts", post.id), {
        likedBy: nextLikedBy,
        likesCount: nextLikedBy.length,
        updatedAt: serverTimestamp(),
      });
    } catch (err: any) {
      console.error("Failed to update like:", err);
      setActionFeedback({ type: "error", text: err?.message || t("error") });
      return;
    }

    if (!isLiked && post.authorId && post.authorId !== user.uid) {
      try {
        const snippet =
          post.content.length > 50
            ? `${post.content.slice(0, 50)}...`
            : post.content;
        await addDoc(collection(db, "notifications"), {
          userId: post.authorId,
          title: `أُعجب ${resolvedCompanyName} بمنشورك`,
          body: snippet ? `"${snippet}"` : "أبدت الشركة إعجابها بمنشورك في المجتمع.",
          type: "COMMUNITY_LIKE",
          actionUrl: "/community",
          link: "/company/community",
          data: {
            postId: post.id,
            senderId: user.uid,
            senderName: resolvedCompanyName,
            action: "LIKE",
          },
          isRead: false,
          createdAt: serverTimestamp(),
        });
      } catch (err) {
        console.warn("Could not send like notification:", err);
      }
    }
  };

  const handleAddComment = async (postId: string) => {
    const user = auth.currentUser;
    const text = (commentInput[postId] || "").trim();
    if (!user || !text || commentingPostId === postId) return;

    try {
      setCommentingPostId(postId);
      await addDoc(collection(db, "communityComments"), {
        postId,
        authorId: user.uid,
        authorName: resolvedCompanyName,
        authorHeadline: resolvedHeadline,
        authorRole: "COMPANY",
        content: text,
        createdAt: serverTimestamp(),
      });
      await updateDoc(doc(db, "communityPosts", postId), {
        commentsCount: increment(1),
        updatedAt: serverTimestamp(),
      });
      setCommentInput((prev) => ({ ...prev, [postId]: "" }));

      const targetPost = posts.find((p) => p.id === postId);
      if (targetPost && targetPost.authorId && targetPost.authorId !== user.uid) {
        try {
          await addDoc(collection(db, "notifications"), {
            userId: targetPost.authorId,
            title: `علّق ${resolvedCompanyName} على منشورك`,
            body: text.length > 80 ? `${text.slice(0, 80)}...` : text,
            type: "COMMUNITY_COMMENT",
            actionUrl: "/community",
            link: "/company/community",
            data: {
              postId,
              senderId: user.uid,
              senderName: resolvedCompanyName,
              action: "COMMENT",
            },
            isRead: false,
            createdAt: serverTimestamp(),
          });
        } catch (err) {
          console.warn("Could not send comment notification:", err);
        }
      }
    } catch (err: any) {
      console.error("Failed to add comment:", err);
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setCommentingPostId(null);
    }
  };

  const handleDeletePost = async (postId: string) => {
    if (
      !window.confirm(
        isRTL
          ? "هل أنت متأكد من حذف هذا المنشور وجميع تعليقاته نهائياً؟"
          : "Are you sure you want to delete this post and all its comments?"
      )
    ) {
      return;
    }

    try {
      setDeletingPostId(postId);
      // Clean up associated comments to avoid orphaned records
      const commentsSnap = await getDocs(
        query(collection(db, "communityComments"), where("postId", "==", postId))
      );
      for (let i = 0; i < commentsSnap.docs.length; i += 400) {
        const batch = writeBatch(db);
        commentsSnap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
      await deleteDoc(doc(db, "communityPosts", postId));
      setActionFeedback({
        type: "success",
        text: isRTL ? "تم حذف المنشور بنجاح." : "Post deleted successfully.",
      });
    } catch (err: any) {
      console.error("Failed to delete post:", err);
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setDeletingPostId(null);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {actionFeedback && (
        <div
          className={`fixed top-6 left-1/2 -translate-x-1/2 z-[99999] shadow-2xl max-w-lg w-[92%] sm:w-auto px-5 py-3.5 rounded-2xl text-xs sm:text-sm font-semibold border flex items-center gap-3 backdrop-blur-md transition-all animate-in fade-in slide-in-from-top-4 duration-200 ${
            actionFeedback.type === "success"
              ? "bg-emerald-600 text-white border-emerald-500 shadow-emerald-500/25"
              : "bg-rose-600 text-white border-rose-500 shadow-rose-500/25"
          }`}
        >
          {actionFeedback.type === "success" ? (
            <CheckCircle2 className="w-5 h-5 shrink-0 text-white" />
          ) : (
            <AlertCircle className="w-5 h-5 shrink-0 text-white" />
          )}
          <span className="flex-1 leading-snug">{actionFeedback.text}</span>
          <button
            type="button"
            onClick={() => setActionFeedback(null)}
            className="p-1 rounded-lg text-white/80 hover:text-white hover:bg-white/10 cursor-pointer"
            aria-label={t("close")}
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
              {isRTL ? "مجتمع التوظيف والخبرات المهنية" : "Professional Community Feed"}
            </h1>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
              {isRTL
                ? "متزامن لحظياً مع تطبيق Test2Hire. شارك مستجدات التوظيف، النصائح الهندسية، وتفاعل مع المرشحين."
                : "Synchronized in real time with the Test2Hire Flutter mobile app. Share hiring updates, engineering insights, and engage with candidates."}
            </p>
          </div>
        </div>

        <form onSubmit={handlePublish} className="space-y-4">
          <textarea
            value={newContent}
            onChange={(e) => setNewContent(e.target.value)}
            rows={3}
            placeholder={
              isRTL
                ? "شارك إعلاناً عن الشركة، فرصة توظيف جديدة، أو نصيحة مهنية للمرشحين..."
                : "Share a company announcement, hiring update, or career advice with candidates..."
            }
            className="w-full rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2 flex-wrap">
              <Tag className="w-4 h-4 text-slate-400" />
              {TOPICS.map((topic) => (
                <button
                  type="button"
                  key={topic.value}
                  onClick={() => setSelectedTag(topic.value)}
                  className={`px-3 py-1 rounded-full text-xs font-semibold transition-colors cursor-pointer ${
                    selectedTag === topic.value
                      ? "bg-indigo-600 text-white"
                      : "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700"
                  }`}
                >
                  {isRTL ? topic.labelAr : topic.labelEn}
                </button>
              ))}
            </div>
            <button
              type="submit"
              disabled={submitting || !newContent.trim()}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-xs font-bold shadow-sm transition-colors cursor-pointer"
            >
              {submitting ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Send className="w-3.5 h-3.5" />}
              <span>
                {submitting
                  ? isRTL
                    ? "جاري النشر..."
                    : "Publishing..."
                  : isRTL
                  ? "نشر في المجتمع"
                  : "Publish to Community"}
              </span>
            </button>
          </div>
        </form>
      </div>

      {loading ? (
        <div className="p-12 flex flex-col items-center justify-center gap-3 text-sm text-slate-500">
          <div className="w-8 h-8 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin" />
          <span>{t("loading")}</span>
        </div>
      ) : posts.length === 0 ? (
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-12 text-center">
          <p className="text-sm text-slate-500 dark:text-slate-400">
            {isRTL
              ? "لا توجد منشورات في المجتمع بعد. ابدأ بنشر أول تحديث أعلاه!"
              : "No community posts yet. Publish the first update above!"}
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {posts.map((post) => {
            const isLiked = currentUid ? post.likedBy.includes(currentUid) : false;
            const isOwner = Boolean(currentUid && post.authorId === currentUid);
            const isExpanded = expandedPostId === post.id;
            const postComments = commentsByPost[post.id] || [];
            const safeAvatarUrl = sanitizeImageUrl(post.authorAvatarUrl);
            const showAvatarImg = Boolean(safeAvatarUrl && !brokenAvatars[post.id]);

            return (
              <div
                key={post.id}
                className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 shadow-sm space-y-3"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3 min-w-0">
                    {showAvatarImg ? (
                      <div className="w-10 h-10 rounded-full overflow-hidden border border-slate-200 dark:border-slate-700 bg-white shrink-0">
                        <img
                          src={safeAvatarUrl!}
                          alt={post.authorName}
                          loading="lazy"
                          decoding="async"
                          className="w-full h-full object-cover"
                          onError={() =>
                            setBrokenAvatars((prev) => ({ ...prev, [post.id]: true }))
                          }
                        />
                      </div>
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-indigo-50 dark:bg-indigo-950 text-indigo-600 dark:text-indigo-400 font-bold flex items-center justify-center shrink-0">
                        {post.authorName.charAt(0).toUpperCase()}
                      </div>
                    )}
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-bold text-sm text-slate-900 dark:text-white truncate">
                          {post.authorName}
                        </span>
                        {post.authorRole === "COMPANY" && (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-50 text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300">
                            <CheckCircle2 className="w-3 h-3" />
                            {isRTL ? "شركة معتمدة" : "Company"}
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-slate-500 dark:text-slate-400 truncate">
                        {post.authorHeadline}
                        {post.createdAt
                          ? ` • ${formatTimestamp(
                              post.createdAt,
                              isRTL ? "ar-EG" : "en-US",
                              undefined,
                              ""
                            )}`
                          : ""}
                      </p>
                    </div>
                  </div>
                  {isOwner && (
                    <button
                      type="button"
                      disabled={deletingPostId === post.id}
                      onClick={() => handleDeletePost(post.id)}
                      className="p-1.5 text-slate-400 hover:text-rose-500 disabled:opacity-50 rounded-lg cursor-pointer shrink-0"
                      title={t("delete")}
                    >
                      {deletingPostId === post.id ? (
                        <Loader2 className="w-4 h-4 animate-spin" />
                      ) : (
                        <Trash2 className="w-4 h-4" />
                      )}
                    </button>
                  )}
                </div>

                <p className="text-sm text-slate-800 dark:text-slate-200 whitespace-pre-line leading-relaxed">
                  {post.content}
                </p>

                {post.tags.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {post.tags.map((tag) => {
                      const topicObj = TOPICS.find((tp) => tp.value === tag);
                      return (
                        <span
                          key={tag}
                          className="px-2.5 py-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-indigo-600 dark:text-indigo-400 text-xs font-semibold"
                        >
                          #{isRTL && topicObj ? topicObj.labelAr : tag}
                        </span>
                      );
                    })}
                  </div>
                )}

                <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center gap-6 text-xs font-semibold text-slate-600 dark:text-slate-400">
                  <button
                    type="button"
                    onClick={() => handleToggleLike(post)}
                    className={`inline-flex items-center gap-1.5 cursor-pointer ${
                      isLiked ? "text-indigo-600 dark:text-indigo-400 font-bold" : "hover:text-indigo-600 dark:hover:text-indigo-400"
                    }`}
                  >
                    <ThumbsUp className="w-4 h-4" />
                    <span>
                      {post.likesCount}{" "}
                      {isRTL
                        ? "إعجاب"
                        : post.likesCount === 1
                        ? "Like"
                        : "Likes"}
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() =>
                      setExpandedPostId(isExpanded ? null : post.id)
                    }
                    className="inline-flex items-center gap-1.5 hover:text-indigo-600 dark:hover:text-indigo-400 cursor-pointer"
                  >
                    <MessageSquare className="w-4 h-4" />
                    <span>
                      {post.commentsCount}{" "}
                      {isRTL
                        ? "تعليق"
                        : post.commentsCount === 1
                        ? "Comment"
                        : "Comments"}
                    </span>
                  </button>
                </div>

                {isExpanded && (
                  <div className="pt-3 border-t border-slate-100 dark:border-slate-800 space-y-3">
                    <div className="space-y-2 max-h-60 overflow-y-auto">
                      {postComments.length === 0 ? (
                        <p className="text-xs text-slate-400 py-2 text-center">
                          {isRTL ? "لا توجد تعليقات بعد." : "No comments yet."}
                        </p>
                      ) : (
                        postComments.map((c) => (
                          <div
                            key={c.id}
                            className="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/70 text-xs space-y-1"
                          >
                            <div className="flex items-center justify-between gap-2">
                              <span className="font-bold text-slate-900 dark:text-white">
                                {c.authorName}
                              </span>
                              <span className="text-[11px] text-slate-400 truncate">
                                {c.authorHeadline}
                              </span>
                            </div>
                            <p className="text-slate-700 dark:text-slate-300">
                              {c.content}
                            </p>
                          </div>
                        ))
                      )}
                    </div>
                    <div className="flex gap-2">
                      <input
                        type="text"
                        value={commentInput[post.id] || ""}
                        onChange={(e) =>
                          setCommentInput((prev) => ({
                            ...prev,
                            [post.id]: e.target.value,
                          }))
                        }
                        onKeyDown={(e) => {
                          if (e.key === "Enter") {
                            e.preventDefault();
                            handleAddComment(post.id);
                          }
                        }}
                        placeholder={isRTL ? "اكتب تعليقاً..." : "Write a comment..."}
                        className="flex-1 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                      <button
                        type="button"
                        disabled={
                          commentingPostId === post.id ||
                          !(commentInput[post.id] || "").trim()
                        }
                        onClick={() => handleAddComment(post.id)}
                        className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-xs font-bold cursor-pointer inline-flex items-center gap-1.5"
                      >
                        {commentingPostId === post.id && (
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        )}
                        <span>{isRTL ? "رد" : "Reply"}</span>
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
