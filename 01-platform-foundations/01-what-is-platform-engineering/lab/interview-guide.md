# Interview Guide — Developer Pain Discovery

A script for a ~15-minute developer pain interview. Adapt it; don't read it
robotically. Your goal is to understand their reality, not to validate an idea you
already have.

## Before you start

- Make it safe: "There are no wrong answers. I'm trying to understand the pain, not
  judge how anyone works."
- Ask permission to take notes and to quote them (anonymously is fine).
- **Listen more than you talk.** Aim for an 80/20 split in their favor.

## Warm-up (2 min)

- What service(s) do you work on? What's your role on the team?
- Walk me through what happens between "I've finished writing code" and "it's
  running in production."

## The core question (6–8 min)

> **What is the most painful part of deploying and operating your service?**

Then **follow the pain** with open follow-ups:

- "Tell me more about that — what exactly happens?"
- "When was the last time that bit you? Walk me through it."
- "Why do you think it works that way?"
- "What do you do when that happens? Who do you ask?"
- "How long does that take? How often?"
- "What have you tried to make it better?"

> The "5 whys" instinct is useful here: keep asking *why* until you hit a root
> cause (a missing capability, unclear ownership, a waiting-on-humans bottleneck),
> not just a surface symptom.

## Probe each friction type (4 min)

Platforms address several kinds of friction. Briefly probe any you haven't heard:

- **Setup friction** — standing up a *new* service/repo/environment.
- **Deployment friction** — getting a change safely to production.
- **Operational friction** — running it: scaling, config, secrets, on-call.
- **Debugging friction** — knowing if it's healthy; finding out what went wrong.
- **Waiting friction** — tickets, approvals, access, other teams.

## Wrap-up (2 min)

- If you had a magic wand and could fix exactly one of these tomorrow, which would
  it be?
- Is there anything I didn't ask about that makes your day harder than it should be?
- Thank them. Ask if you can follow up.

## Note-taking tips

- Capture **verbatim quotes** — they're persuasive and preserve nuance.
- Separate what they **say** (symptom) from what you **infer** (root cause); mark
  your inferences as inferences.
- Jot the **frequency** and **cost** of each pain ("daily, ~30 min" vs. "rare but
  catastrophic") — you'll rank by these later.
