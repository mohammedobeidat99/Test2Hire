import { redirect } from "next/navigation";

export default function RootHome() {
  redirect("/login");
}
