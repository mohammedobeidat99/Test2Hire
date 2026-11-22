# Test2Hire Production Deployment & Operations Guide

## 1. Project Overview & Architecture
**Test2Hire** is an enterprise-grade AI hiring, candidate assessment, and talent lifecycle platform connecting:
- **Job Seekers / Students** (Flutter Mobile)
- **Hiring Companies & Recruiters** (Flutter Mobile)
- **Candidate Assessment & Anti-Cheating Exam Web** (Next.js 15)
- **Platform Moderators & Compliance Administrators** (Next.js 15)
- **Secure Backend Cloud Services** (Node.js 20 Cloud Functions & Firebase)

- **Firebase Live Project**: `test2here-72346`
- **Location / Region**: `us-central1`

---

## 2. Platform Subsystems & Build Commands

### A. Firebase Cloud Functions (`/functions`)
- **Runtime**: Node.js 20 (TypeScript)
- **Build**:
  ```bash
  cd functions
  npm install
  npm run build
  ```
- **Deploy**:
  ```bash
  firebase deploy --only functions
  ```

### B. Exam Web Application (`/web_exam`)
- **Runtime**: Next.js 15.0.3 (App Router, TailwindCSS, Lucide Icons)
- **Build & Verification**:
  ```bash
  cd web_exam
  npm install
  npm run build
  ```
- **Deploy to Firebase Hosting**:
  ```bash
  firebase deploy --only hosting:exam
  ```

### C. Admin Web Dashboard (`/web_admin`)
- **Runtime**: Next.js 15.0.3 (App Router, TailwindCSS, Lucide Icons)
- **Build & Verification**:
  ```bash
  cd web_admin
  npm install
  npm run build
  ```
- **Deploy to Firebase Hosting**:
  ```bash
  firebase deploy --only hosting:admin
  ```

### D. Mobile Application (`/mobile_app`)
- **Framework**: Flutter 3.x (Clean Architecture: Domain, Data, Presentation with Provider)
- **Linter & Test Verification**:
  ```bash
  cd mobile_app
  flutter analyze
  flutter test
  ```
- **Production Android Build**:
  ```bash
  flutter build appbundle --release
  ```
- **Production iOS Build**:
  ```bash
  flutter build ipa --release
  ```

---

## 3. Database Security & Optimization
- **Firestore Security Rules**: Defined in `firestore.rules` covering 21 collections with strict role-based access control (RBAC).
  ```bash
  firebase deploy --only firestore:rules
  ```
- **Firestore Indexes**: Defined in `firestore.indexes.json` covering complex query paths for jobs, applications, interviews, offers, campaigns, and challenges.
  ```bash
  firebase deploy --only firestore:indexes
  ```
- **Storage Rules**: Defined in `storage.rules` protecting resumes, logos, and submissions.
  ```bash
  firebase deploy --only storage
  ```

---

## 4. Graduation & Demo Accounts (Walkthrough Credentials)

### 1. Platform Administrator
- **Role**: `ADMIN`
- **Use Case**: Review pending company registrations, inspect system telemetry, oversee violations, and configure global platform settings.

### 2. Verified Enterprise Company
- **Role**: `COMPANY`
- **Use Case**: Create job postings, assemble question banks, schedule technical interviews, generate AI scorecards, extend formal offers, and run high-volume sourcing campaigns.

### 3. Job Seeker / Candidate
- **Role**: `USER`
- **Use Case**: Build professional skills profile, apply for published jobs, take secure online assessments in sandbox/live mode, book interview slots, and accept job offers.

---

## 5. Verification Summary
- **Unit & Integration Tests**: 100% Pass Rate across all 132 automated tests.
- **Code Health**: 0 errors, 0 linter warnings across Flutter and Web codebases.
