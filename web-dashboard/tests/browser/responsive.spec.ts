import { test, expect, type Page } from "@playwright/test";
import { mockDashboard } from "./fixtures";

async function expectNoOverflow(page: Page, context: string) {
  const layout = await page.evaluate(() => {
    const width = document.documentElement.clientWidth;
    const outside = [...document.querySelectorAll("body *")]
      .filter((element) => {
        if (element.closest("nextjs-portal")) return false;
        const box = element.getBoundingClientRect();
        return (
          box.width > 0 &&
          box.height > 0 &&
          (box.left < -1 || box.right > width + 1)
        );
      })
      .slice(0, 8)
      .map((element) => ({
        tag: element.tagName,
        class: element.className,
        text: element.textContent?.slice(0, 40),
      }));
    return {
      width,
      scrollWidth: document.documentElement.scrollWidth,
      outside,
    };
  });
  expect
    .soft(layout.scrollWidth, context + ": document width")
    .toBeLessThanOrEqual(layout.width + 1);
  expect
    .soft(layout.outside, context + ": elements beyond viewport")
    .toEqual([]);
}

test("entry forms fit narrow phones, tablets and desktops", async ({
  page,
}) => {
  await page.goto("/");
  for (const width of [320, 390, 768, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    for (const name of ["دخول", "انضمام", "مجموعة جديدة"]) {
      await page.getByRole("button", { name, exact: true }).click();
      await expectNoOverflow(page, name + " at " + width);
    }
  }
});

test("all dashboard sections and dialogs fit long content without horizontal overflow", async ({
  page,
}, testInfo) => {
  test.setTimeout(90000);
  await mockDashboard(page, true);
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "آخر المصاريف" }),
  ).toBeVisible();
  for (const width of [320, 390, 768, 1024, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    const navigation = page.getByRole("navigation", {
      name: width < 850 ? "التنقل على الهاتف" : "التنقل الرئيسي",
    });
    for (const name of [
      "الرئيسية",
      "المصاريف",
      "المجموعة",
      "الإشعارات",
      "الإعدادات",
    ]) {
      await navigation
        .getByRole("button", {
          name: name === "الإشعارات" ? /الإشعارات/ : name,
          exact: name !== "الإشعارات",
        })
        .click();
      await expectNoOverflow(page, name + " at " + width);
    }
    await page
      .getByRole("button", { name: "إضافة مصروف", exact: true })
      .click();
    await expect(page.getByRole("dialog")).toBeVisible();
    await expectNoOverflow(page, "expense dialog at " + width);
    await page.getByRole("button", { name: "إغلاق", exact: true }).click();
  }
  await page.setViewportSize({ width: 320, height: 900 });
  await page.screenshot({
    path: testInfo.outputPath("narrow-settings.png"),
    fullPage: true,
  });
});
