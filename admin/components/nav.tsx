"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

type Item = { href: string; label: string; badge?: number };

export function Nav({ items }: { items: Item[] }) {
  const pathname = usePathname();
  return (
    <nav className="flex flex-row gap-1 overflow-x-auto md:flex-col">
      {items.map((item) => {
        const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center justify-between gap-3 whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium ${
              active ? "bg-red-50 text-red-800" : "text-gray-700 hover:bg-gray-100"
            }`}
          >
            {item.label}
            {!!item.badge && (
              <span className="rounded-full bg-red-600 px-2 py-0.5 text-xs font-semibold text-white">
                {item.badge}
              </span>
            )}
          </Link>
        );
      })}
    </nav>
  );
}
