# Test2Hire — AI-Powered Talent Lifecycle & Assessment Ecosystem

Test2Hire is an enterprise-ready recruitment, technical assessment, and talent lifecycle ecosystem connecting candidates and hiring companies with automated AI evaluations, real-time proctored examinations, take-home practical challenges, and scheduled interviews.

---

## 🏛️ Ecosystem Architecture

The platform consists of four unified subsystems:

| Subsystem | Technology | Path | Description |
| :--- | :--- | :--- | :--- |
| **Mobile Application** | Flutter (Dart 3, Provider, Material 3) | [`/mobile_app`](./mobile_app) | Multi-role iOS & Android app for Candidates & Hiring Companies (Job Feed, Community, Applications, Assessments, Interviews, Offers, Notifications). |
| **Admin & Company Web** | Next.js 15 (React 19, TailwindCSS, TypeScript) | [`/web_admin`](./web_admin) | Company recruiting portal for posting jobs, managing applicants, creating/editing exams, assigning practical tasks, and scheduling interviews. |
| **Online Exam Portal** | Next.js 15 (WebRTC, Audio Analyser, Canvas) | [`/web_exam`](./web_exam) | Secure proctored exam runner for candidates with real-time camera/microphone verification, draggable HUD, tab-switch violation detection, and snapshot audit trails. |
| **Backend Cloud Functions**| Node.js 20, TypeScript, Firebase Cloud Functions | [`/functions`](./functions) | Cloud backend orchestrating AI resume parsing, automated exam evaluations, violation limit termination, proctoring snapshots, and real-time push notifications. |

---

## 🚀 Getting Started & Local Setup

### Prerequisites
- **Node.js**: v20 or higher
- **Flutter SDK**: 3.24+ (Dart 3.5+)
- **Firebase CLI**: `npm install -g firebase-tools`
- **Git**

---

### 1. Backend Cloud Functions (`/functions`)

```bash
cd functions
npm install
cp .env.example .env # Add your Google Gemini API key
npm run build
```

---

### 2. Company & Admin Web Portal (`/web_admin`)

```bash
cd web_admin
npm install
cp .env.local.example .env.local # Configure environment variables
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

---

### 3. Candidate Examination Portal (`/web_exam`)

```bash
cd web_exam
npm install
npm run dev
```
Open [http://localhost:3000/exam/[token]](http://localhost:3000) with a valid examination token.

---

### 4. Mobile Application (`/mobile_app`)

```bash
cd mobile_app
flutter pub get
flutter run
```

---

## 🔒 Security & Anti-Cheating Highlights

- **Proctoring Hardware Checks**: Live microphone volume analyser and webcam verification prior to exam start.
- **Floating Proctoring HUD**: Draggable, dockable webcam preview ensuring candidate awareness throughout the exam session.
- **Three-Strike Violation Rules**: Automatic termination and zero-score recording on repeated tab switches or fullscreen exits, instantly reported to the company portal with webcam snapshots.
- **Candidate Data Isolation**: Multi-layered Firestore security rules and state cleanup ensuring strict cross-candidate isolation for exams, applications, and take-home assignments.

---

## 📄 License
This project is proprietary and confidential.
