import { Nav } from "@/components/nav";
import { requireAdmin } from "@/lib/auth";
import { signOut } from "../login/actions";

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const { supabase, user, role } = await requireAdmin();
  const { data: stats } = await supabase.rpc("admin_dashboard");
  const pending = Number(stats?.pending_approvals ?? 0);

  const items = [
    { href: "/", label: "Dashboard" },
    { href: "/channels", label: "Channels" },
    { href: "/posts", label: "Posts" },
    ...(role === "owner"
      ? [
          { href: "/approvals", label: "Approvals", badge: pending },
          { href: "/users", label: "Users" },
          { href: "/plans", label: "Plans" },
          { href: "/admins", label: "Admins" },
        ]
      : []),
  ];

  return (
    <div className="min-h-screen md:flex">
      <aside className="border-b border-gray-200 bg-white p-4 md:sticky md:top-0 md:h-screen md:w-60 md:shrink-0 md:border-b-0 md:border-r">
        <div className="mb-4 flex items-center gap-2 md:mb-6">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-red-700 text-sm font-bold text-white">
            CS
          </div>
          <span className="font-semibold">Cloud Storage</span>
        </div>
        <Nav items={items} />
        <div className="mt-4 border-t border-gray-200 pt-4 md:absolute md:bottom-4 md:left-4 md:right-4">
          <p className="truncate text-xs text-gray-500" title={user.email ?? ""}>
            {user.email}
          </p>
          <p className="mb-2 text-xs font-medium text-gray-700">
            {role === "owner" ? "Owner" : "Content admin"}
          </p>
          <form action={signOut}>
            <button className="text-sm font-medium text-red-700 hover:underline">Sign out</button>
          </form>
        </div>
      </aside>
      <main className="flex-1 p-4 md:p-8">{children}</main>
    </div>
  );
}
