const messages: Record<string, string> = {
  legacy_anon_required:
    "يتطلب إعداد مسكن الحالي مفتاح anon العام المتوافق مع تسجيل الدخول.",
  configuration_required:
    "يلزم إعداد عنوان Supabase والمفتاح العام لتشغيل التطبيق.",
  invalid_amount: "أدخل مبلغًا موجبًا، بمنزلتين عشريتين كحد أقصى.",
  invalid_credentials:
    "تعذر تسجيل الدخول. تحقق من اسم المجموعة والعضو وكلمة المرور.",
  duplicate_network: "اسم المجموعة مستخدم بالفعل.",
  duplicate_member: "اسم العضو مستخدم في هذه المجموعة.",
  rate_limited: "محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.",
  permission_denied: "لا تملك صلاحية تنفيذ هذه العملية.",
  session_required: "انتهت الجلسة. سجّل الدخول مجددًا.",
  confirmation_required: "يرجى تأكيد الحذف قبل المتابعة.",
  cycle_changed: "تغيرت الدورة. حدّث البيانات ثم أعد المحاولة.",
  operation_conflict:
    "استُخدم رقم العملية نفسه لبيانات مختلفة. حدّث الصفحة وتحقق من المصروف قبل المحاولة مجددًا.",
  network_busy:
    "تجري عملية أخرى على المجموعة. حدّث البيانات ثم أعد المحاولة مع الاحتفاظ ببيانات المصروف.",
  pending_request: "يوجد طلب دورة جديدة قيد الموافقة.",
  owner_transfer_required:
    "يجب نقل ملكية المجموعة أو معالجة عضويتها قبل حذف الحساب.",
  invalid_request: "تحقق من الحقول المطلوبة.",
};
export function errorMessage(error: unknown) {
  const code =
    error instanceof Error ? error.message : (error as { code?: string })?.code;
  return (
    messages[code ?? ""] ??
    "تعذر إتمام العملية. تحقق من الاتصال وحدّث البيانات قبل إعادة المحاولة."
  );
}
