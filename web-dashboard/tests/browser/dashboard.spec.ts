import { test, expect } from "@playwright/test";
import { mockDashboard } from "./fixtures";
test("Arabic account entry is responsive and supports all existing entry modes", async ({
  page,
}) => {
  await page.goto("/");
  await expect(
    page.getByRole("button", { name: "الدخول إلى مسكن" }),
  ).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await page.getByRole("button", { name: "انضمام", exact: true }).click();
  await expect(page.getByLabel("كلمة مرور المجموعة")).toBeVisible();
  await page.getByRole("button", { name: "مجموعة جديدة", exact: true }).click();
  await expect(page.getByLabel("عملة المجموعة")).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
});
test("authenticated dashboard shows real response totals, opens editor, filters history, and switches theme", async ({
  page,
}, testInfo) => {
  const { expenseRows, getExpenseInserts } = await mockDashboard(page);
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "آخر المصاريف" }),
  ).toBeVisible();
  await expect(page.getByText("مشتريات البيت", { exact: true })).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("dashboard-light.png"),
    fullPage: true,
  });
  await page.getByRole("button", { name: "إضافة مصروف", exact: true }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByLabel("المبلغ (USD)").fill("20.55");
  await page.getByLabel("ملاحظة", { exact: true }).fill("مصروف من المتصفح");
  await page.getByRole("button", { name: "حفظ المصروف", exact: true }).click();
  await expect(page.getByRole("dialog")).not.toBeVisible();
  await expect(
    page.getByText("مصروف من المتصفح", { exact: true }),
  ).toBeVisible();
  expect(getExpenseInserts()).toBe(1);
  expect(expenseRows[1].amount_cents).toBe(2055);
  await page.getByRole("button", { name: "تبديل المظهر" }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  const navigation =
    page.viewportSize()!.width < 850
      ? page.getByRole("navigation", { name: "التنقل على الهاتف" })
      : page.getByRole("navigation", { name: "التنقل الرئيسي" });
  await navigation
    .getByRole("button", { name: "المصاريف", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "سجل المصاريف" }),
  ).toBeVisible();
  await page.getByLabel("البحث", { exact: true }).fill("لا يوجد");
  await expect(
    page.getByRole("heading", { name: "لا توجد مصاريف هنا بعد" }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
});
