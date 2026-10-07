import type { Metadata } from "next";
import { requestDeletion } from "@/app/public-actions/support";
import { PublicPage } from "@/components/public-page";
import { SupportForm } from "@/components/support-form";

export const metadata: Metadata = { title: "Flixvault — Delete your account", robots: { index: true } };

// Account deletion page required by Google Play (Data safety → delete account URL).
export default function DeleteAccountPage() {
  return (
    <PublicPage title="Delete your Flixvault account">
      <div className="mb-8 space-y-4 text-gray-700">
        <div>
          <h2 className="mb-1 font-semibold text-gray-900">Option 1 — in the app (instant)</h2>
          <p>Open Flixvault → <b>Profile</b> → <b>⚙ Settings</b> → <b>Delete Account</b> → confirm.</p>
        </div>
        <div>
          <h2 className="mb-1 font-semibold text-gray-900">Option 2 — request it here</h2>
          <p>Enter the email address of your Flixvault account. We delete the account and reply by email within 7 days.</p>
        </div>
        <div className="rounded-xl bg-gray-50 p-4 text-sm">
          <p className="font-semibold text-gray-900">What is deleted</p>
          <p>Your profile, the files in your cloud storage, your channel memberships, and channels and posts you created.</p>
          <p className="mt-2 font-semibold text-gray-900">What we keep</p>
          <p>Payment records (order number, amount, date, UPI reference) for accounting and fraud prevention, as required by law.</p>
        </div>
      </div>
      <SupportForm
        action={requestDeletion}
        fields={[
          { name: "email", label: "Account email", type: "email", required: true, placeholder: "you@gmail.com" },
          { name: "reason", label: "Reason (optional)", textarea: true },
        ]}
        confirm="I want my Flixvault account and its data to be permanently deleted."
        submit="Request account deletion"
      />
    </PublicPage>
  );
}
