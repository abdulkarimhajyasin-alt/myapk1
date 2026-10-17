import { useState } from "react";
import type { Snapshot } from "@/lib/types";
import { MaskanRepository } from "@/lib/repository";
import { money, settle } from "@/lib/money";
import type { RunAction } from "./dashboard";
import { Avatar, Icon } from "./icons";
type Props = {
  s: Snapshot;
  repo: MaskanRepository;
  run: RunAction;
  busy: boolean;
};
export function GroupPanel({ s, repo, run, busy }: Props) {
  const totals = settle(s.members, s.expenses);
  const pending = s.requests.find((r) => r.status === "pending");
  const owner = s.network.created_by_member_id === s.me.id;
  const [copied, setCopied] = useState(false);
  const [copyError, setCopyError] = useState(false);
  return (
    <div className="panel-grid">
      <section className="card">
        <div className="section-heading">
          <div>
            <h2>{s.network.name}</h2>
            <p>
              {s.members.length} أعضاء · {s.network.currency_code}
            </p>
          </div>
          <Icon name="group" />
        </div>
        {totals.balances.map((m) => (
          <div className="member-row" key={m.id}>
            <Avatar
              initials={
                s.members.find((member) => member.id === m.id)?.avatar_initials
              }
              name={m.name}
              color={
                s.members.find((member) => member.id === m.id)?.avatar_color
              }
            />
            <div>
              <strong>
                {m.name} {m.id === s.me.id ? "(أنت)" : ""}
              </strong>
              <small>
                {m.id === s.network.created_by_member_id
                  ? "مالك المجموعة"
                  : "عضو"}
              </small>
            </div>
            <div className="member-balance">
              <b>{money(m.balance, s.network.currency_symbol)}</b>
              <small>
                {m.balance > 0.5
                  ? "مستحق له"
                  : m.balance < -0.5
                    ? "مستحق عليه"
                    : "متوازن"}
              </small>
            </div>
          </div>
        ))}
        <div className="invite">
          <h3>المشاركة تبدأ بدعوة</h3>
          <p>
            شارك الرابط واسم المجموعة، وأرسل كلمة مرور المجموعة للشخص المدعو
            بشكل منفصل.
          </p>
          <button
            className="secondary"
            onClick={async () => {
              try {
                await navigator.clipboard.writeText(
                  window.location.origin +
                    "/?network=" +
                    encodeURIComponent(s.network.id),
                );
                setCopied(true);
                setCopyError(false);
              } catch {
                setCopyError(true);
              }
            }}
          >
            {copied ? "تم نسخ الرابط" : "نسخ رابط الدعوة"}
          </button>
          {copyError && (
            <p role="alert">
              تعذر النسخ. معرّف المجموعة: <bdi>{s.network.id}</bdi>
            </p>
          )}
        </div>
      </section>
      <section className="card">
        <div className="section-heading">
          <div>
            <h2>دورات المصاريف</h2>
            <p>كل دورة تحتفظ بسجلّها</p>
          </div>
        </div>
        {pending ? (
          <div className="cycle-callout">
            <span className="pill">بانتظار الموافقات</span>
            <h3>طلب {pending.requested_by_member_name} دورة جديدة</h3>
            <p>
              {
                s.approvals.filter((a) => a.reset_request_id === pending.id)
                  .length
              }{" "}
              من {pending.required_member_ids.length} موافقات
            </p>
            <p>
              تعني الموافقة إقرارك بالتسوية وأرشفة المصاريف عند اكتمال موافقات
              الجميع.
            </p>
            {pending.required_member_ids.includes(s.me.id) && (
              <button
                className="primary"
                disabled={busy}
                onClick={() => {
                  if (
                    window.confirm(
                      "هل توافق على تسوية الدورة الحالية وبدء دورة جديدة بعد موافقة الجميع؟",
                    )
                  )
                    void run(
                      () => repo.approveCycle(s, pending),
                      "تم تسجيل الموافقة",
                    );
                }}
              >
                {s.approvals.some(
                  (a) =>
                    a.reset_request_id === pending.id &&
                    a.member_id === s.me.id,
                )
                  ? "التحقق من اكتمال الموافقات"
                  : "الموافقة على الطلب"}
              </button>
            )}
          </div>
        ) : (
          <div className="cycle-callout">
            <h3>جاهزون لبداية جديدة؟</h3>
            <p>
              {owner
                ? "بصفتك المالك يمكنك بدء دورة جديدة مباشرة. تُؤرشف المصاريف الحالية وتبدأ الأرصدة من الصفر."
                : "اطلب دورة جديدة؛ تبدأ بعد موافقة جميع الأعضاء المسجلين في الطلب."}
            </p>
            <button
              className="secondary"
              disabled={busy}
              onClick={() => {
                if (
                  window.confirm(
                    owner
                      ? "تأكيد بدء دورة جديدة وأرشفة المصاريف الحالية؟"
                      : "إرسال طلب دورة جديدة إلى جميع الأعضاء؟",
                  )
                )
                  void run(() => repo.requestCycle(s), "تمت متابعة طلب الدورة");
              }}
            >
              {owner ? "بدء دورة جديدة" : "طلب دورة جديدة"}
            </button>
          </div>
        )}
        {s.cycles
          .slice()
          .reverse()
          .map((c) => (
            <div className="cycle-row" key={c.id}>
              <div>
                <strong>الدورة {c.cycle_number}</strong>
                <small>{new Date(c.started_at).toLocaleDateString("ar")}</small>
              </div>
              <span className="pill">
                {c.status === "closed"
                  ? "مؤرشفة"
                  : c.status === "pending_reset" || pending?.cycle_id === c.id
                    ? "بانتظار الموافقات"
                    : "جارية"}
              </span>
            </div>
          ))}
      </section>
    </div>
  );
}
export function SettingsPanel({
  s,
  repo,
  run,
  busy,
  dark,
  toggleTheme,
}: Props & { dark: boolean; toggleTheme: () => void }) {
  const owner = s.me.id === s.network.created_by_member_id;
  const otherMembers = s.members.filter((m) => m.id !== s.me.id);
  const [deleteOpen, setDeleteOpen] = useState(false);
  return (
    <div className="panel-grid">
      <section className="card">
        <div className="section-heading">
          <h2>الملف الشخصي</h2>
          <Icon name="settings" />
        </div>
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            const data = new FormData(e.currentTarget);
            await run(() =>
              repo.profile(
                s,
                String(data.get("initials")),
                String(data.get("color")),
              ),
            );
          }}
        >
          <fieldset disabled={busy}>
            <label>
              اسم العضو
              <input value={s.me.name} readOnly />
            </label>
            <label>
              حروف الصورة الشخصية
              <input
                name="initials"
                maxLength={3}
                required
                defaultValue={s.me.avatar_initials || s.me.name.slice(0, 2)}
              />
            </label>
            <label>
              لون الصورة
              <input
                name="color"
                type="color"
                defaultValue={
                  /^#[0-9a-f]{6}$/i.test(s.me.avatar_color ?? "")
                    ? s.me.avatar_color!
                    : "#0c7161"
                }
              />
            </label>
            <button className="primary" type="submit">
              حفظ الملف الشخصي
            </button>
          </fieldset>
        </form>
        <hr />
        <div className="section-heading">
          <div>
            <h3>المظهر</h3>
            <p>اختر ما يناسبك</p>
          </div>
          <button className="secondary" onClick={toggleTheme}>
            {dark ? "المظهر الفاتح" : "المظهر الداكن"}
          </button>
        </div>
        <h3>مسكن على الشاشة الرئيسية</h3>
        <p className="muted">
          على iPhone: افتح قائمة المشاركة في Safari، ثم اختر «إضافة إلى الشاشة
          الرئيسية». يحتاج تحديث المصاريف إلى اتصال بالإنترنت.
        </p>
      </section>
      <section className="card">
        <div className="section-heading">
          <h2>الحساب والأمان</h2>
        </div>
        {owner && otherMembers.length > 0 ? (
          <form
            onSubmit={async (e) => {
              e.preventDefault();
              const form = e.currentTarget;
              const data = new FormData(form);
              if (
                await run(
                  () =>
                    repo.resetPassword(
                      s,
                      String(data.get("member")),
                      String(data.get("password")),
                    ),
                  "تمت إعادة تعيين كلمة المرور",
                )
              )
                form.reset();
            }}
          >
            <fieldset disabled={busy}>
              <h3>إعادة تعيين كلمة مرور عضو</h3>
              <label>
                العضو
                <select name="member">
                  {otherMembers.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                كلمة المرور الجديدة
                <input
                  type="password"
                  name="password"
                  required
                  minLength={4}
                  autoComplete="new-password"
                />
              </label>
              <button className="secondary" type="submit">
                إعادة تعيين كلمة المرور
              </button>
            </fieldset>
          </form>
        ) : (
          <p className="muted">
            يمكن لمالك المجموعة إعادة تعيين كلمات مرور الأعضاء. تغيير كلمة مرور
            المالك ذاتيًا غير مدعوم حاليًا.
          </p>
        )}
        <hr />
        <h3>تبديل المجموعة</h3>
        <p className="muted">
          يرتبط الحساب الحالي بعضوية واحدة. سجّل الخروج ثم ادخل ببيانات عضويتك
          في المجموعة الأخرى.
        </p>
        <button
          className="secondary"
          disabled={busy}
          onClick={() => void run(() => repo.logout(), "تم تسجيل الخروج")}
        >
          تسجيل الخروج
        </button>
        <hr />
        <h3>مغادرة المجموعة</h3>
        <p className="muted">
          تتاح المغادرة عندما لا توجد مصاريف نشطة. تُطبَّق قواعد الملكية على
          الخادم.
        </p>
        <button
          className="secondary"
          disabled={busy || settle(s.members, s.expenses).total > 0}
          onClick={() => {
            if (window.confirm("هل تريد مغادرة هذه المجموعة؟"))
              void run(() => repo.leave(s), "تمت المغادرة");
          }}
        >
          مغادرة المجموعة
        </button>
        <hr />
        <h3 className="danger-text">حذف الحساب نهائيًا</h3>
        <p className="muted">
          لا يمكن التراجع عن الحذف. ستُطبّق قيود الملكية وحماية السجلات المالية
          قبل تنفيذ العملية.
        </p>
        <button
          className="danger"
          disabled={busy}
          onClick={() => setDeleteOpen((v) => !v)}
        >
          متابعة حذف الحساب
        </button>
        {deleteOpen && (
          <form
            className="delete-form"
            onSubmit={async (e) => {
              e.preventDefault();
              const data = new FormData(e.currentTarget);
              if (data.get("confirm") !== "on") return;
              if (window.confirm("تأكيد أخير: هل تريد حذف حسابك نهائيًا؟"))
                await run(
                  () =>
                    repo.deleteAccount(
                      String(data.get("password")),
                      data.get("network") === "on",
                    ),
                  "تم حذف الحساب",
                );
            }}
          >
            <fieldset disabled={busy}>
              <label>
                كلمة مرور العضو
                <input
                  type="password"
                  name="password"
                  required
                  autoComplete="current-password"
                />
              </label>
              <label className="checkbox">
                <input name="confirm" type="checkbox" required />
                أفهم أن الحذف نهائي
              </label>
              {s.members.length === 1 && (
                <label className="checkbox">
                  <input name="network" type="checkbox" required />
                  أوافق على حذف المجموعة لأنني العضو الأخير
                </label>
              )}
              <button type="submit" className="danger">
                تأكيد حذف الحساب
              </button>
            </fieldset>
          </form>
        )}
      </section>
    </div>
  );
}
