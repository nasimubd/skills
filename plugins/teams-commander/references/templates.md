# Message templates

The message types the user sends most often (from October 2026 sessions). Every
`<placeholder>` that states a fact needs a claim with evidence; `?` lines are
questions. Keep only the lines the recipient needs.

## Review request

```
Hi <name>, <change> is ready for your review. Nothing in production has changed.

- What changes: <one line>
- Tested: <result, with the number>
- Rollback: <one line>

Details are in <file>. Could you review it by <date>?
```

## Go-live approval

```
Hi <name>, <change> is tested and ready to go live.

- Tested: <what, with numbers>
- Go-live steps: <one line>
- Rollback: <one command / one line>

OK to go live <when>?
```

## Decisions needed

```
Hi <name>, before I build <task name> I need your decision on <n> points:

1. <question>?
2. <question>?

Context is in <file>. Nothing has been changed yet.
```

## Access request

```
Hi <name>, for <task> I need <access> to <resource> (<id>). It isn't shared with my
account, so I get <error>.

Could you add me (<email>) as <role>? I'll only <read/export> it for now.
```

## End-of-day report (at most two sentences)

```
Today <what went live/was done>: <metric> went from <before> to <after>. <second fact
with a number, or the next step>.
```

## Reply to questions

```
Thanks <name>. <answer to question 1, one or two sentences>.

On <topic of question 2>: <answer>.
```

## Follow-up

```
Hi <name>, following up on <topic> from <day>. <what is still needed>?
```
