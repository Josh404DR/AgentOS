import asyncio
import json
import os
from pathlib import Path
from playwright.async_api import async_playwright

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        # Search query
        query = "Google Apps Script"
        url = f"https://www.upwork.com/nx/search/jobs/?q={query}&sort=recency"
        print(f"Navigating to {url}...")

        leads = []
        try:
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)

            # Wait for content
            try:
                await page.wait_for_selector("[data-test='job-tile-list']", timeout=30000)
            except:
                print("Job list not found, might be blocked or no results.")
                # Save page source for debugging
                content = await page.content()
                # Dynamically construct path relative to the AgentOS root directory
                root_dir = Path(__file__).resolve().parents[2]
                captures_dir = root_dir / "scratch" / "captures"
                os.makedirs(captures_dir, exist_ok=True)
                page_source_path = captures_dir / "page_source.html"
                with open(page_source_path, "w", encoding="utf-8") as f:
                     f.write(content)
                screenshot_dir = root_dir / "assets" / "upwork"
                os.makedirs(screenshot_dir, exist_ok=True)
                screenshot_path = screenshot_dir / "upwork_debug.png"
                await page.screenshot(path=str(screenshot_path))
                return

            jobs = await page.query_selector_all("[data-test='job-tile-list'] > section")
            print(f"Found {len(jobs)} jobs.")

            for job in jobs:
                title_elem = await job.query_selector("h2 a")
                title = await title_elem.inner_text() if title_elem else "N/A"
                link = await title_elem.get_attribute("href") if title_elem else "N/A"
                if link and link.startswith("/"):
                    link = "https://www.upwork.com" + link

                # Check for budget
                budget_text = ""
                budget_fixed = await job.query_selector("[data-test='is-fixed-price']")
                if budget_fixed:
                    budget_text = await budget_fixed.inner_text()

                # Check for hourly range
                hourly = await job.query_selector("[data-test='job-type']")
                if hourly and not budget_text:
                    budget_text = await hourly.inner_text()

                posted_elem = await job.query_selector("[data-test='posted-on']")
                posted = await posted_elem.inner_text() if posted_elem else "N/A"

                desc_elem = await job.query_selector("[data-test='job-description-text']")
                desc = await desc_elem.inner_text() if desc_elem else "N/A"

                # Extract client info if possible
                client_location = "N/A"
                loc_elem = await job.query_selector("[data-test='client-country']")
                if loc_elem:
                    client_location = await loc_elem.inner_text()

                leads.append({
                    "title": title,
                    "url": link,
                    "budget": budget_text,
                    "posted": posted,
                    "desc": desc,
                    "location": client_location
                })

        except Exception as e:
            print(f"An error occurred: {e}")

        await browser.close()

        # Save results to JSON
        root_dir = Path(__file__).resolve().parents[2]
        leads_dir = root_dir / "data" / "leads"
        os.makedirs(leads_dir, exist_ok=True)
        leads_path = leads_dir / "leads.json"
        with open(leads_path, "w", encoding="utf-8") as f:
            json.dump(leads, f, indent=2)
        print(f"Saved {len(leads)} leads to {leads_path}")

if __name__ == "__main__":
    asyncio.run(run())
