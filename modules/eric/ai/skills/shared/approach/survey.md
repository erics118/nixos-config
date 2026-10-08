# Survey

How to decide which mechanism should do a job. If something does the job today, it gets no credit for existing. It is one candidate among the others.

1. Job. Restate the job in one line as an outcome. Name no mechanism (the script, service, or tool that does or would do the job), but do name the inputs it must honor. If something does the job today, read it first and list every behavior it provides. Each one is either an input the job must honor or a loss the verdict names.
2. Survey. Fill every slot with its source: a doc or man page you read, `path:line`, or a command and its output. Write `none` for an empty slot and say where you looked.
   - Platform: what the OS, init system, language, or framework already provides for this job
   - Standard tools: the usual tool for this job outside this repo
   - Repo: what this repo already does for it. Search by the job, not the current names, and search basenames and paths built from variables before calling anything unused
   - Zero-code: don't build it, delete it, or leave it as is
   - Project rules: any rule in the project instructions that constrains the answer
3. Candidates. List only candidates that fully do the job, simplest first. Don't pad the list. Give each a `Quality:` line on the five checks in the Decisions rules of the global instructions. Quality decides the pick. A candidate's cost is where it falls short on quality, plus what it takes to run. Also list the behavior it loses. The work to get there only breaks a tie.
4. Strongest objection. Write the best case against your pick as the user would put it, and the fact that answers it.
5. Verdict. `Verdict: <pick> - <the deciding fact>` and `Would change if: <a fact, not a preference>`. When the evidence doesn't settle it, write `Verdict: hold - <what to check>`. On a hold, run that check if a fact can settle it, or `grilling` if only the user can, then write the verdict again.
