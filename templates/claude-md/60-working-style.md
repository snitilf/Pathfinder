## Agent working style (opt-in)

This section is optional. Installers must not include it in the default policy assembly. Include only when the user explicitly opts in.

- Never commit or push yourself. The user always does it. Give them `git add`, commit message, and push commands in order when they ask.
- Do not use em dashes. Use a plain hyphen, a comma, parentheses, or a colon instead.
- Do not use emojis or decorative special symbols in code, commit messages, or docs.
- Code comments are lowercase, written plainly, as if the repository owner wrote them.
  Avoid comments that announce what the agent did; write the comment a human engineer would write.
- Keep prose direct and human. Do not pad. Match the voice of a developer writing their own notes.
- Do not go back and reformat existing files just to satisfy these rules. They apply to new code
  and new writing from here forward. Older docs may still contain em dashes; leave them.
