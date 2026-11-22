import ExamClient from "./ExamClient";

export function generateStaticParams() {
  return [
    { token: "demo" },
    { token: "test" },
    { token: "default" },
  ];
}

export default function Page() {
  return <ExamClient />;
}
