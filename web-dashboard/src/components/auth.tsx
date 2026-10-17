import { useRef, useState } from "react";
import { currencies, MaskanRepository } from "@/lib/repository";
import { errorMessage } from "@/lib/errors";
import { Brand, Icon } from "./icons";
export function Auth({
  repo,
  onSuccess,
}: {
  repo: MaskanRepository;
  onSuccess: () => Promise<void>;
}) {
  const [mode, setMode] = useState<"login" | "join" | "create">("login");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const lock = useRef(false);
  const ids = useRef<{ memberId: string; networkId: string } | null>(null);
  return (
    <main className="auth-shell">
      <section className="auth-story">
        <Brand />
        <div>
          <span className="eyebrow">بيتنا واحد. حساباتنا واضحة.</span>
          <h1>
            مصاريف مشتركة،
            <br />
            <em>حياة أبسط.</em>
          </h1>
          <p>
            كل ما يخص مصاريف سكنك في مكان واحد.
            <br />
            سجّل، شارك، واعرف حقّك بسهولة.
          </p>
          <div className="story-house">
            <Icon name="home" size={100} />
            <span className="story-badge">
              <Icon name="check" /> حسابات واضحة للجميع
            </span>
          </div>
        </div>
        <small>مسكن · من Karamix Labs</small>
      </section>
      <section className="auth-panel">
        <div className="mobile-brand">
          <Brand />
        </div>
        <span className="eyebrow">أهلًا بك في مسكن</span>
        <h2>
          {mode === "login"
            ? "بيتك وحساباتك، بانتظارك"
            : mode === "join"
              ? "انضم إلى أهل البيت"
              : "بداية جديدة لمجموعتك"}
        </h2>
        <p className="muted">استخدم بيانات مسكن نفسها على Android وiPhone.</p>
        <div className="segmented" aria-label="خيارات الحساب">
          {(
            [
              ["login", "دخول"],
              ["join", "انضمام"],
              ["create", "مجموعة جديدة"],
            ] as const
          ).map(([key, label]) => (
            <button
              type="button"
              key={key}
              disabled={busy}
              aria-pressed={mode === key}
              onClick={() => {
                setMode(key);
                setError("");
                ids.current = null;
              }}
            >
              {label}
            </button>
          ))}
        </div>
        <form
          key={mode}
          onSubmit={async (event) => {
            event.preventDefault();
            if (lock.current) return;
            lock.current = true;
            setBusy(true);
            setError("");
            const form = new FormData(event.currentTarget);
            const value = (key: string) => String(form.get(key) ?? "");
            try {
              if (mode === "login")
                await repo.login(
                  value("networkName"),
                  value("memberName"),
                  value("memberPassword"),
                );
              else {
                ids.current ??= {
                  memberId: crypto.randomUUID(),
                  networkId: crypto.randomUUID(),
                };
                await repo.register(
                  mode,
                  {
                    networkName: value("networkName"),
                    memberName: value("memberName"),
                    memberPassword: value("memberPassword"),
                    networkPassword: value("networkPassword"),
                    currencyCode: value("currencyCode") || "USD",
                    networkId: value("networkId") || undefined,
                  },
                  ids.current,
                );
              }
              await onSuccess();
            } catch (e) {
              setError(errorMessage(e));
            } finally {
              lock.current = false;
              setBusy(false);
            }
          }}
        >
          <fieldset disabled={busy}>
            <label>
              اسم المجموعة
              <input
                name="networkName"
                required
                maxLength={120}
                autoComplete="organization"
                placeholder="اسم مجموعة السكن"
              />
            </label>
            <label>
              اسم العضو
              <input
                name="memberName"
                required
                maxLength={120}
                autoComplete="username"
                placeholder="اسمك داخل المجموعة"
              />
            </label>
            {mode !== "login" && (
              <label>
                كلمة مرور المجموعة
                <input
                  name="networkPassword"
                  type="password"
                  required
                  autoComplete="off"
                />
              </label>
            )}
            <label>
              كلمة مرور العضو
              <input
                name="memberPassword"
                type="password"
                required
                minLength={mode === "login" ? 1 : 4}
                autoComplete={
                  mode === "login" ? "current-password" : "new-password"
                }
              />
            </label>
            {mode === "join" && (
              <label>
                معرّف المجموعة (اختياري)
                <input
                  name="networkId"
                  dir="ltr"
                  pattern="[0-9a-fA-F-]{36}"
                  defaultValue={
                    new URLSearchParams(window.location.search).get(
                      "network",
                    ) ?? ""
                  }
                />
              </label>
            )}
            {mode === "create" && (
              <label>
                عملة المجموعة
                <select name="currencyCode">
                  {Object.entries(currencies).map(([code, symbol]) => (
                    <option key={code} value={code}>
                      {code} · {symbol}
                    </option>
                  ))}
                </select>
              </label>
            )}
            {error && (
              <p role="alert" className="notice error">
                {error}
              </p>
            )}
            <button className="primary full" type="submit">
              {busy
                ? "جارٍ المتابعة…"
                : mode === "login"
                  ? "الدخول إلى مسكن"
                  : mode === "join"
                    ? "انضمام إلى المجموعة"
                    : "إنشاء المجموعة"}
              <Icon name="arrow" size={18} />
            </button>
          </fieldset>
        </form>
        <details className="help">
          <summary>نسيت كلمة المرور؟</summary>
          <p>
            اطلب من مالك المجموعة إعادة تعيين كلمة مرورك من إعدادات الأعضاء.
            استعادة كلمة مرور المالك ذاتيًا غير متاحة حاليًا.
          </p>
        </details>
        <p className="auth-foot">وضوح في الحسابات. راحة في المشاركة.</p>
      </section>
    </main>
  );
}
