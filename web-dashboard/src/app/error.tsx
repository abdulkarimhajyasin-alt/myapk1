"use client";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return (
    <main className="setup card">
      <h1>تعذر عرض هذه البيانات</h1>
      <p>
        حدّث الصفحة للتحقق من أحدث بيانات المجموعة. لم تُرسل أي عملية مالية من
        هذه الشاشة.
      </p>
      <button className="primary" onClick={reset}>
        إعادة المحاولة
      </button>
    </main>
  );
}
