import { useCallback, useEffect, useRef, useState } from "react";
import { getClient } from "@/lib/client";
import { MaskanRepository, canEdit } from "@/lib/repository";
import { errorMessage } from "@/lib/errors";
import { money, parseCents, settle } from "@/lib/money";
import { watchNetwork } from "@/lib/realtime";
import type { Expense, Snapshot } from "@/lib/types";
import { Auth } from "./auth";
import { Avatar, Brand, Icon } from "./icons";
import { GroupPanel, SettingsPanel } from "./panels";

const tabs = [
  { id: "home", label: "الرئيسية", icon: "home" },
  { id: "expenses", label: "المصاريف", icon: "expenses" },
  { id: "group", label: "المجموعة", icon: "group" },
  { id: "notifications", label: "الإشعارات", icon: "bell" },
  { id: "settings", label: "الإعدادات", icon: "settings" },
] as const;
type Tab = (typeof tabs)[number]["id"];
export type RunAction = (
  action: () => Promise<void>,
  success?: string,
) => Promise<boolean>;
export function Dashboard() {
  let repo: MaskanRepository;
  try {
    repo = new MaskanRepository(getClient());
  } catch (e) {
    return (
      <main className="setup card">
        <Brand />
        <h1>مرحبًا بك في مسكن</h1>
        <p role="alert">{errorMessage(e)}</p>
        <p className="muted">
          يمكن لمسؤول تشغيل الموقع إكمال الإعداد ثم إعادة تحميل الصفحة.
        </p>
      </main>
    );
  }
  return <Workspace initialRepo={repo} />;
}
function Workspace({ initialRepo }: { initialRepo: MaskanRepository }) {
  const [repo] = useState(initialRepo);
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>("home");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [connection, setConnection] = useState("جارٍ الاتصال");
  const [dark, setDark] = useState(() => {
    try {
      return localStorage.getItem("maskan-theme") === "dark";
    } catch {
      return false;
    }
  });
  const [editor, setEditor] = useState<Expense | "new" | null>(null);
  const [history, setHistory] = useState("active");
  const [search, setSearch] = useState("");
  const [memberFilter, setMemberFilter] = useState("");
  const lock = useRef(false);
  const generation = useRef(0);
  const refresh = useCallback(async () => {
    const request = ++generation.current;
    try {
      const next = await repo.snapshot();
      if (request === generation.current) {
        setSnapshot(next);
      }
    } catch (e) {
      if (request === generation.current) setError(errorMessage(e));
    } finally {
      if (request === generation.current) setLoading(false);
    }
  }, [repo]);
  useEffect(() => {
    const counter = generation;
    const timer = setTimeout(() => void refresh(), 0);
    return () => {
      clearTimeout(timer);
      counter.current++;
    };
  }, [refresh]);
  useEffect(() => {
    const { data } = repo.client.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT") {
        generation.current++;
        setSnapshot(null);
        setEditor(null);
        setLoading(false);
      }
    });
    return () => data.subscription.unsubscribe();
  }, [repo]);
  const networkId = snapshot?.network.id,
    memberId = snapshot?.me.id;
  useEffect(() => {
    if (!networkId || !memberId) return;
    return watchNetwork(
      repo.client,
      networkId,
      memberId,
      refresh,
      setConnection,
    );
  }, [repo, networkId, memberId, refresh]);
  useEffect(() => {
    document.documentElement.dataset.theme = dark ? "dark" : "light";
    try {
      localStorage.setItem("maskan-theme", dark ? "dark" : "light");
    } catch {
      /* Theme storage is optional. */
    }
  }, [dark]);
  const run: RunAction = async (action, success = "تم حفظ التغييرات") => {
    if (lock.current) return false;
    lock.current = true;
    setBusy(true);
    setError("");
    setMessage("");
    repo.clearWarning();
    try {
      await action();
      setMessage(repo.warning ?? success);
      await refresh();
      return true;
    } catch (e) {
      await refresh();
      setError(errorMessage(e));
      return false;
    } finally {
      lock.current = false;
      setBusy(false);
    }
  };
  if (loading)
    return (
      <main className="loading" aria-busy="true">
        <Brand />
        <p>جارٍ تحميل مساحتك…</p>
      </main>
    );
  if (!snapshot)
    return (
      <>
        <Auth repo={repo} onSuccess={refresh} />
        {error && (
          <div className="global-error notice error" role="alert">
            {error}
            <button
              onClick={() => {
                setError("");
                void refresh();
              }}
            >
              إعادة المحاولة
            </button>
          </div>
        )}
      </>
    );
  const s = snapshot;
  const totals = settle(s.members, s.expenses);
  const mine = totals.balances.find((m) => m.id === s.me.id)!;
  const format = (value: number) => money(value, s.network.currency_symbol);
  const active = s.expenses.filter((e) => e.archived_at === null);
  const filtered = s.expenses
    .filter(
      (e) =>
        (history === "all" ||
          (history === "active"
            ? e.archived_at === null
            : e.cycle_id === history)) &&
        (!memberFilter || e.paid_by_member_id === memberFilter) &&
        (!search ||
          [e.note, e.paid_by_member_name, e.added_by_member_name].some((t) =>
            t?.includes(search),
          )),
    )
    .slice()
    .reverse();
  const unread = s.notifications.filter((n) => !n.is_read).length;
  const expenseList = (items: Expense[]) =>
    items.length ? (
      <div className="expense-list">
        {items.map((e) => (
          <article className="expense-row" key={e.id}>
            <span className="expense-icon">
              <Icon name="expenses" />
            </span>
            <div className="expense-info">
              <strong>{e.note || "مصروف مشترك"}</strong>
              <small>
                دفع {e.paid_by_member_name} ·{" "}
                {new Date(e.created_at).toLocaleDateString("ar")}{" "}
                {e.archived_at ? "· مؤرشف" : ""}
              </small>
            </div>
            <div className="expense-end">
              <b className="amount">{format(e.amount_cents)}</b>
              {canEdit(e, s.me.id) && (
                <div className="row-actions">
                  <button disabled={busy} onClick={() => setEditor(e)}>
                    تعديل
                  </button>
                  <button
                    disabled={busy}
                    className="danger-text"
                    onClick={() => {
                      if (window.confirm("هل تريد حذف هذا المصروف نهائيًا؟"))
                        void run(
                          () => repo.deleteExpense(s, e),
                          "تم حذف المصروف",
                        );
                    }}
                  >
                    حذف
                  </button>
                </div>
              )}
            </div>
          </article>
        ))}
      </div>
    ) : (
      <div className="empty">
        <Icon name="expenses" size={36} />
        <h3>لا توجد مصاريف هنا بعد</h3>
        <p>ابدأ بإضافة أول مصروف، وستظهر تفاصيله للجميع.</p>
      </div>
    );
  return (
    <div className="workspace">
      <aside className="sidebar">
        <Brand />
        <span className="nav-caption">مساحتك المشتركة</span>
        <nav aria-label="التنقل الرئيسي">
          {tabs.map((t) => (
            <button
              key={t.id}
              className={tab === t.id ? "selected" : ""}
              aria-current={tab === t.id ? "page" : undefined}
              onClick={() => setTab(t.id)}
            >
              <Icon name={t.icon} />
              <span>{t.label}</span>
              {t.id === "notifications" && unread > 0 && (
                <span className="badge">{unread}</span>
              )}
            </button>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="group-mini">
            <Icon name="group" />
            <div>
              <strong>{s.network.name}</strong>
              <small>{s.members.length} أعضاء · بيت واحد</small>
            </div>
          </div>
          <button
            className="quiet"
            disabled={busy}
            onClick={() => void run(() => repo.logout(), "تم تسجيل الخروج")}
          >
            <Icon name="logout" />
            تسجيل الخروج
          </button>
          <small>مسكن · Karamix Labs</small>
        </div>
      </aside>
      <div className="main-area">
        <header className="topbar">
          <div className="breadcrumb">
            مساحتي <span>/</span> {tabs.find((t) => t.id === tab)?.label}
          </div>
          <div className="top-actions">
            <span className="connection">
              <i />
              {connection}
            </span>
            <button
              className="icon-button"
              aria-label="تبديل المظهر"
              onClick={() => setDark((v) => !v)}
            >
              <Icon name="moon" />
            </button>
            <button
              className="icon-button"
              aria-label="تحديث البيانات"
              disabled={busy}
              onClick={() => {
                setError("");
                void refresh();
              }}
            >
              <Icon name="refresh" />
            </button>
            <Avatar
              initials={s.me.avatar_initials}
              name={s.me.name}
              color={s.me.avatar_color}
            />
          </div>
        </header>
        <main id="content">
          <div className="page-heading">
            <div>
              <span className="eyebrow">{s.network.name}</span>
              <h1>
                {tab === "home"
                  ? "أهلًا، " + s.me.name + " 👋"
                  : tabs.find((t) => t.id === tab)?.label}
              </h1>
              <p className="muted">
                {tab === "home"
                  ? "نظرة واضحة على مصاريف بيتك، وكل ما يخصك."
                  : "كل التفاصيل بين يديك، ومحدّثة مع مجموعتك."}
              </p>
            </div>
            <button
              className="primary"
              disabled={busy}
              onClick={() => setEditor("new")}
            >
              <Icon name="plus" size={19} />
              إضافة مصروف
            </button>
          </div>
          {error && (
            <p className="notice error" role="alert">
              {error}
            </p>
          )}
          {message && (
            <p className="notice" role="status">
              {message}
            </p>
          )}
          {tab === "home" && (
            <>
              <section className="summary-grid" aria-label="ملخص الدورة">
                <article className="balance-card">
                  <div className="card-label">
                    <span>رصيدي الحالي</span>
                    <Icon name="wallet" />
                  </div>
                  <strong className="balance-number">
                    {format(mine.balance)}
                  </strong>
                  <span>
                    {mine.balance > 0.5
                      ? "مبلغ مستحق لك من المجموعة"
                      : mine.balance < -0.5
                        ? "مبلغ مستحق عليك للمجموعة"
                        : "حسابك متوازن"}
                  </span>
                  <div className="balance-footer">
                    <span>نصيبك {format(totals.share)}</span>
                    <Icon name="arrow" />
                  </div>
                </article>
                {[
                  [
                    "إجمالي مصاريف الدورة",
                    totals.total,
                    "expenses",
                    "مصاريف البيت في الدورة الحالية",
                  ],
                  ["مساهماتي", mine.paid, "wallet", "إجمالي ما دفعته للمجموعة"],
                  [
                    "أعضاء المجموعة",
                    s.members.length,
                    "group",
                    "نتشارك المصاريف بالتساوي",
                  ],
                ].map(([label, value, icon, caption], i) => (
                  <article className="stat-card card" key={String(label)}>
                    <div className="card-label">
                      <span>{label}</span>
                      <span className="soft-icon">
                        <Icon name={String(icon)} />
                      </span>
                    </div>
                    <strong>{i === 2 ? value : format(Number(value))}</strong>
                    <small>{caption}</small>
                  </article>
                ))}
              </section>
              <div className="dashboard-grid">
                <section className="card recent">
                  <div className="section-heading">
                    <div>
                      <h2>آخر المصاريف</h2>
                      <p>تفاصيل صغيرة، صورة أوضح</p>
                    </div>
                    <button
                      className="text-button"
                      onClick={() => setTab("expenses")}
                    >
                      عرض الكل ←
                    </button>
                  </div>
                  {expenseList(active.slice(-5).reverse())}
                </section>
                <section className="card distribution">
                  <div className="section-heading">
                    <div>
                      <h2>مساهمات أهل البيت</h2>
                      <p>توزيع المبالغ المدفوعة</p>
                    </div>
                  </div>
                  <div className="distribution-total">
                    <span>الإجمالي</span>
                    <strong>{format(totals.total)}</strong>
                  </div>
                  {totals.balances.map((m, i) => (
                    <div className="bar-row" key={m.id}>
                      <div>
                        <span>
                          <i
                            style={{
                              background: [
                                "#0c8573",
                                "#68bbaa",
                                "#dda869",
                                "#758fa7",
                              ][i % 4],
                            }}
                          />
                          {m.name}
                          {m.id === s.me.id ? " (أنت)" : ""}
                        </span>
                        <b>{format(m.paid)}</b>
                      </div>
                      <meter
                        min={0}
                        max={Math.max(1, totals.total)}
                        value={m.paid}
                        aria-label={"مساهمة " + m.name}
                      />
                    </div>
                  ))}
                </section>
                <section className="card settlement">
                  <div className="section-heading">
                    <div>
                      <h2>تسوية الحسابات</h2>
                      <p>من يدفع لمن؟ وفق المصاريف الحالية</p>
                    </div>
                    <span className="pill">الدورة الحالية</span>
                  </div>
                  {totals.payments.length ? (
                    totals.payments.map((p, i) => (
                      <div className="settlement-row" key={i}>
                        <span>
                          {s.members.find((m) => m.id === p.from)?.name}
                        </span>
                        <span className="muted">← يدفع إلى ←</span>
                        <span>
                          {s.members.find((m) => m.id === p.to)?.name}
                        </span>
                        <b>{format(p.amount)}</b>
                      </div>
                    ))
                  ) : (
                    <p className="empty-small">
                      لا توجد مبالغ تحتاج إلى تسوية.
                    </p>
                  )}
                  <p className="muted footnote">
                    هذه حسابات مقترحة للتسوية؛ لا تُنفّذ تحويلات مالية.
                  </p>
                </section>
              </div>
            </>
          )}
          {tab === "expenses" && (
            <section className="card">
              <div className="section-heading">
                <div>
                  <h2>سجل المصاريف</h2>
                  <p>{filtered.length} عملية · حسب الفلاتر المحددة</p>
                </div>
              </div>
              <div className="filters">
                <label>
                  البحث
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="ملاحظة أو اسم عضو"
                  />
                </label>
                <label>
                  الدورة
                  <select
                    value={history}
                    onChange={(e) => setHistory(e.target.value)}
                  >
                    <option value="active">الحالية</option>
                    <option value="all">جميع المصاريف</option>
                    {s.cycles.map((c) => (
                      <option key={c.id} value={c.id}>
                        الدورة {c.cycle_number}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  العضو
                  <select
                    value={memberFilter}
                    onChange={(e) => setMemberFilter(e.target.value)}
                  >
                    <option value="">الجميع</option>
                    {s.members.map((m) => (
                      <option key={m.id} value={m.id}>
                        {m.name}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              {expenseList(filtered)}
            </section>
          )}
          {tab === "group" && (
            <GroupPanel s={s} repo={repo} run={run} busy={busy} />
          )}
          {tab === "notifications" && (
            <section className="card">
              <div className="section-heading">
                <h2>إشعارات المجموعة</h2>
                <span className="pill">{unread} غير مقروءة</span>
              </div>
              {s.notifications.length ? (
                s.notifications.map((n) => (
                  <article
                    className={"notification " + (!n.is_read ? "unread" : "")}
                    key={n.id}
                  >
                    <span className="soft-icon">
                      <Icon name="bell" />
                    </span>
                    <div>
                      <strong>{n.actor_member_name}</strong>
                      <p>
                        {n.kind === "expense"
                          ? "أضاف مصروفًا بقيمة " + format(n.amount_cents)
                          : n.kind === "expenseUpdated" ||
                              n.kind === "expense_updated"
                            ? "عدّل مصروفًا إلى " + format(n.amount_cents)
                            : n.kind === "resetRequest" ||
                                n.kind === "reset_request"
                              ? "طلب بدء دورة جديدة"
                              : "بدأت دورة مصاريف جديدة"}
                      </p>
                      {n.note_snippet && (
                        <p className="muted">{n.note_snippet}</p>
                      )}
                      <small>
                        {new Date(n.created_at).toLocaleString("ar")}
                      </small>
                      <div className="row-actions">
                        {!n.is_read && (
                          <button
                            disabled={busy}
                            onClick={() =>
                              void run(
                                () => repo.markRead(s, n.id),
                                "تم تحديد الإشعار كمقروء",
                              )
                            }
                          >
                            تحديد كمقروء
                          </button>
                        )}
                        <button
                          disabled={busy}
                          onClick={() =>
                            void run(
                              () => repo.deleteNotification(s, n.id),
                              "تم حذف الإشعار",
                            )
                          }
                        >
                          حذف
                        </button>
                      </div>
                    </div>
                  </article>
                ))
              ) : (
                <div className="empty">
                  <Icon name="bell" size={36} />
                  <h3>أنت على اطلاع بكل شيء</h3>
                  <p>ستظهر هنا تحديثات مجموعتك.</p>
                </div>
              )}
            </section>
          )}
          {tab === "settings" && (
            <SettingsPanel
              s={s}
              repo={repo}
              run={run}
              busy={busy}
              dark={dark}
              toggleTheme={() => setDark((v) => !v)}
            />
          )}
          <footer className="page-footer">
            <span>مسكن · مشاركة عادلة، حياة أهدأ</span>
            <span>العملة: {s.network.currency_code}</span>
          </footer>
        </main>
      </div>
      <nav className="mobile-nav" aria-label="التنقل على الهاتف">
        {tabs.map((t) => (
          <button
            key={t.id}
            aria-current={tab === t.id ? "page" : undefined}
            onClick={() => setTab(t.id)}
          >
            <Icon name={t.icon} size={21} />
            <span>{t.label}</span>
          </button>
        ))}
      </nav>
      {editor && (
        <ExpenseEditor
          key={editor === "new" ? "new" : editor.id}
          expense={editor === "new" ? null : editor}
          s={s}
          busy={busy}
          serverError={error}
          close={() => setEditor(null)}
          save={async (payer, amount, note, id) => {
            const ok = await run(
              () =>
                editor === "new"
                  ? repo.addExpense(s, payer, amount, note, id)
                  : repo.editExpense(s, editor, amount, note),
              "تم حفظ المصروف",
            );
            if (ok) setEditor(null);
            return ok;
          }}
        />
      )}
    </div>
  );
}
function ExpenseEditor({
  serverError,
  expense,
  s,
  busy,
  close,
  save,
}: {
  serverError: string;
  expense: Expense | null;
  s: Snapshot;
  busy: boolean;
  close: () => void;
  save: (
    payer: string,
    amount: number,
    note: string,
    id: string,
  ) => Promise<boolean>;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const operation = useRef(crypto.randomUUID());
  const attempted = useRef<string | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="expense-dialog"
      onCancel={(e) => {
        e.preventDefault();
        if (!busy) close();
      }}
    >
      <div className="section-heading">
        <h2>{expense ? "تعديل المصروف" : "إضافة مصروف جديد"}</h2>
        <button
          className="icon-button"
          disabled={busy}
          onClick={close}
          aria-label="إغلاق"
        >
          ×
        </button>
      </div>
      <p className="muted">مصروف واحد، حساب واضح للجميع.</p>
      <form
        onSubmit={async (event) => {
          event.preventDefault();
          setError("");
          const data = new FormData(event.currentTarget);
          try {
            const payer = String(data.get("payer"));
            const amount = parseCents(String(data.get("amount")));
            const note = String(data.get("note"));
            const signature = JSON.stringify([payer, amount, note]);
            if (attempted.current !== null && attempted.current !== signature) {
              operation.current = crypto.randomUUID();
            }
            attempted.current = signature;
            const ok = await save(
              payer,
              amount,
              note,
              operation.current,
            );
            if (!ok)
              setError(
                "تعذر الحفظ. راجع الرسالة في الصفحة وتحقق من الاتصال قبل إعادة المحاولة.",
              );
          } catch (e) {
            setError(errorMessage(e));
          }
        }}
      >
        <fieldset disabled={busy}>
          <label>
            المبلغ ({s.network.currency_code})
            <input
              name="amount"
              inputMode="decimal"
              dir="ltr"
              required
              autoFocus
              defaultValue={
                expense ? (expense.amount_cents / 100).toFixed(2) : ""
              }
              placeholder="0.00"
            />
          </label>
          <label>
            من دفع؟
            <select
              name="payer"
              defaultValue={expense?.paid_by_member_id ?? s.me.id}
              disabled={!!expense}
            >
              {s.members.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            ملاحظة
            <textarea
              name="note"
              maxLength={200}
              rows={3}
              defaultValue={expense?.note ?? ""}
              placeholder="مثل: مشتريات المنزل"
            />
          </label>
          {error && (
            <p className="notice error" role="alert">
              {serverError || error}
            </p>
          )}
          <button className="primary full" type="submit">
            {busy ? "جارٍ الحفظ…" : "حفظ المصروف"}
          </button>
        </fieldset>
      </form>
    </dialog>
  );
}
