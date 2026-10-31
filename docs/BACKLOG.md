# Backlog

- Edit and delete tracked senders in Settings (Phase 2 asked only for adding them).
- Regex match rules for tracked senders, if "contains" proves too loose.
- Show `ignored` stale lines somewhere, so a message skipped after a clock change can be recovered.
- Update SPEC 3.3: `inbox.jsonl` is now claimed by rename and deleted, not truncated.
- Show the ignored count in Settings. Ignored messages are invisible today, which hid a misconfigured Shortcut during Phase 2 testing.
- The manual sheet's category dropdown asserts if a row's category is archived. Handle this when archiving is built (SPEC 5.9); such rows also show the grey placeholder in the list.
- Colour and icon choice for new categories (Phase 3 asks only for a name).
- Clear a row's category back to uncategorised.
- Refresh the selected month when the app resumes in a new month.
- Parser: add a template for real HDFC UPI credits ("Credit Alert! Rs.1.00 credited to HDFC Bank A/c XX1541 on 31-10-26 from VPA ... (UPI ...)"). One landed in Unparsed on the iPhone on 2026-10-31; the current credit template covers only the "deposited" NEFT wording.
- Show a trace when a message is skipped as an already-seen fingerprint. It leaves no new log row today, so a Shortcut resending the same wrong text looks exactly like the automation not firing.
