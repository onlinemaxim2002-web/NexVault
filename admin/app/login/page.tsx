import { Button, Field, Input } from "@/components/ui";
import { signIn } from "./actions";

const errors: Record<string, string> = {
  invalid: "Wrong email or password.",
  not_admin: "This account doesn't have admin access.",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-red-700 text-xl font-bold text-white">
            CS
          </div>
          <h1 className="text-xl font-semibold">Cloud Storage Admin</h1>
          <p className="mt-1 text-sm text-gray-500">Sign in to manage content and users</p>
        </div>
        <form action={signIn} className="space-y-4 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          {error && (
            <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
              {errors[error] ?? "Sign-in failed."}
            </p>
          )}
          <Field label="Email">
            <Input name="email" type="email" autoComplete="email" required />
          </Field>
          <Field label="Password">
            <Input name="password" type="password" autoComplete="current-password" required />
          </Field>
          <Button type="submit" className="w-full">
            Sign in
          </Button>
        </form>
      </div>
    </main>
  );
}
