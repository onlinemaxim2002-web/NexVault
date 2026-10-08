import type { Metadata } from "next";
import { reportContent } from "@/app/public-actions/support";
import { PublicPage } from "@/components/public-page";
import { SupportForm } from "@/components/support-form";

export const metadata: Metadata = { title: "NexVault — Report content / copyright", robots: { index: true } };

// Copyright (DMCA) and content reports.
export default function ReportContentPage() {
  return (
    <PublicPage title="Report content or copyright">
      <div className="mb-8 space-y-3 text-gray-700">
        <p>
          All NexVault channels are created by users and reviewed by our team. If you find content that breaks our
          Community Guidelines, or your copyrighted work was posted without permission, tell us below.
        </p>
        <p className="text-sm">
          For copyright complaints please include a link to the content, a description of your original work, and how
          we can contact you. Reported content that infringes copyright is removed promptly, and repeat infringers lose
          their accounts.
        </p>
      </div>
      <SupportForm
        action={reportContent}
        fields={[
          { name: "name", label: "Your name", required: true },
          { name: "email", label: "Your email", type: "email", required: true },
          { name: "content_url", label: "Channel or post (name or link)", placeholder: "e.g. channel name, post title" },
          { name: "details", label: "What is wrong? (for copyright: describe your original work)", textarea: true, required: true },
        ]}
        confirm="I believe in good faith that this content is not allowed, and the information I give is accurate. For copyright complaints, I am the owner or authorised to act for the owner."
        submit="Send report"
      />
    </PublicPage>
  );
}
