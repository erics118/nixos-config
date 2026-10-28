package main

import (
	"slices"
	"strings"
)

// valueOpts lists, per program, the options that take a value and how many words that value is,
// so a value is never read as a command, a path, or a subcommand
var valueOpts = map[string]map[string]int{
	"env":            opts("-u -C -S -P -a --unset --chdir --split-string --argv0"),
	"bash":           opts("-o +o -O +O --rcfile --init-file"),
	"python":         opts("-c -m -W -X -Q"),
	"node":           opts("-e -p -r -C --eval --print --require --import --loader --input-type --conditions"),
	"ruby":           opts("-e -r -I -C -E -F"),
	"perl":           opts("-e -E -I -M -m -F"),
	"sed":            opts("-e -f -l --expression --file --line-length"),
	"awk":            opts("-f -v -F --file --assign --field-separator"),
	"trap":           opts(""),
	"npx":            opts("-p -c --package --call"),
	"uvx":            opts("-p --from --with --python --index"),
	"uv run":         opts("-w -p --with --python --project --directory --env-file --group --extra --package --index --from"),
	"pnpm exec":      opts("-C -F --dir --filter"),
	"nix-shell":      opts("-p -I -A --run --command --packages --attr --arg:2 --argstr:2"),
	"darwin-rebuild": opts("-I -j -p --flake --option:2 --profile-name --max-jobs --cores --builders"),
	"git":            opts("-C -c --git-dir --work-tree --namespace --config-env --attr-source"),
	"git checkout":   opts("-b -B --orphan --conflict --pathspec-from-file"),
	"git switch":     opts("-c -C --create --force-create --orphan --conflict"),
	"git restore":    opts("-s --source --conflict --pathspec-from-file"),
	"git reset":      opts("--pathspec-from-file"),
	"git clean":      opts("-e --exclude"),
	"git stash":      opts("-m --message"),
	"git worktree":   opts("-b -B --reason"),
	"git difftool":   opts("-x -t --extcmd --tool"),
	"gh pr checkout": opts("-b -R --branch --repo"),
	"exec":           opts("-a"),
	"doas":           opts("-u -C"),
	"ionice":         opts("-c -n -p -P -u --class --classdata --pid --pgid --uid"),
	"caffeinate":     opts("-w -t"),
	"stdbuf":         opts("-i -o -e --input --output --error"),
	"xcrun":          opts("--sdk --toolchain -sdk"),
	"flock":          opts("-w -E -c --timeout --wait --conflict-exit-code --command"),
	"sudo":           opts("-u -g -p -C -D -h -R -T -U --user --group --prompt --close-from --chdir --host --role --type --other-user --command-timeout"),
	"nice":           opts("-n --adjustment"),
	"timeout":        opts("-s -k --signal --kill-after"),
	"gtimeout":       opts("-s -k --signal --kill-after"),
	"xargs":          opts("-I -J -R -n -P -L -d -E -s -a --max-args --max-lines --max-procs --delimiter --max-chars --arg-file --process-slot-var"),
	"watch":          opts("-n -q --interval --equexit"),
	"arch":           opts("-arch -d -e"),
	"sandbox-exec":   opts("-f -n -p -D"),
	"script":         opts("-t -T -I -O -B -E -m -c --command"),
	"nix": opts("-I --include --expr -f --file --inputs-from --extra-experimental-features --experimental-features --log-format " +
		"--store --eval-store --max-jobs -j --cores --reference-lock-file --option:2 --override-input:2 --arg:2 --argstr:2"),
	"head":             opts("-n -c --lines --bytes"),
	"tail":             opts("-n -c --lines --bytes"),
	"pkill":            opts("-F -G -g -P -s -t -U -u -L -c --signal --older-than --younger-than"),
	"killall":          opts("-F -G -g -P -s -t -U -u -L -c --signal --older-than --younger-than"),
	"rex":              opts("-S --server -C --client --timeout --color -s --session -b --block --origin --args -e --eval -a --action --for"),
	"sort":             opts("-o -S -T -k -t --output --buffer-size --temporary-directory --key --field-separator --compress-program --files0-from --batch-size --parallel --random-source"),
	"tree":             opts("-o -L -P -I -H -T --charset --filelimit --timefmt --sort"),
	"uniq":             opts("-f -s -w --skip-fields --skip-chars --check-chars"),
	"cp":               opts("-t -S --target-directory --suffix"),
	"mv":               opts("-t -S --target-directory --suffix"),
	"ln":               opts("-t -S --target-directory --suffix"),
	"install":          opts("-m -o -g -t -S --mode --owner --group --target-directory --suffix"),
	"rsync":            opts("-e -f -T -B --rsh --filter --exclude --include --rsync-path --log-file --password-file --files-from --temp-dir --partial-dir --backup-dir --suffix --chmod --chown --timeout --port --block-size --max-size --min-size --compare-dest --copy-dest --link-dest"),
	"truncate":         opts("-s -r --size --reference"),
	"mkdir":            opts("-m --mode"),
	"touch":            opts("-t -d -r --date --reference"),
	"git worktree add": opts("-b -B --reason"),
	"git commit":       opts("-m -F -C -c -t --message --file --reuse-message --reedit-message --author --date --template --cleanup --fixup --squash --trailer"),
	"git push":         opts("-o --push-option --repo --receive-pack --exec"),
	"git pull":         opts("-o --push-option --upload-pack --depth --deepen --shallow-since --shallow-exclude -s --strategy -X --strategy-option"),
	"git fetch":        opts("-o --upload-pack --depth --deepen --shallow-since --shallow-exclude -j --jobs --refmap --negotiation-tip --server-option"),
	"git rebase":       opts("--onto -s --strategy -X --strategy-option -x --exec"),
	"git branch":       opts("-u -t --set-upstream-to --track --contains --no-contains --merged --no-merged --points-at --sort --format"),
	"tmux":             opts("-L -S -f -T -c"),
	// the tmux subcommands that run a shell command, which tmuxScripts reads
	"tmux new-session":    opts("-c -e -F -n -s -t -x -y -f"),
	"tmux new-window":     opts("-c -e -F -n -t"),
	"tmux split-window":   opts("-c -e -F -l -t -p"),
	"tmux respawn-pane":   opts("-c -e -t"),
	"tmux respawn-window": opts("-c -e -t"),
	"tmux run-shell":      opts("-c -d -t"),
	"tmux display-popup":  opts("-b -c -d -e -h -s -S -t -T -w -x -y"),
	"tmux pipe-pane":      opts("-t"),
	"tmux if-shell":       opts("-t"),
	"rg": opts("-e -f --regexp --file -t -T -g -m -A -B -C -M -j -r -d -E --type --type-not --glob --iglob --max-count --context --after-context " +
		"--before-context --max-columns --threads --sort --sortr --pre --pre-glob --hostname-bin --hyperlink-format --colors --color " +
		"--encoding --engine --path-separator --replace --max-depth --max-filesize --ignore-file --type-add --type-clear " +
		"--field-match-separator --field-context-separator --context-separator"),
	"fd": opts("-t -e -E -d -x -X -S -c -j --type --extension --exclude --max-depth --min-depth --exact-depth --changed-within " +
		"--changed-before --owner --size --color --format --max-results --threads --batch-size --and --ignore-file --path-separator " +
		"--search-path --base-directory"),
	"grep": opts("-e -f --regexp --file -m -A -B -C -d -D --include --exclude --exclude-dir --label --color --colour --max-count --context " +
		"--after-context --before-context --binary-files --devices --directories"),
}

// these name another program's grammar
var sameOpts = map[string]string{"egrep": "grep", "fgrep": "grep", "ugrep": "grep", "pgrep": "pkill", "gawk": "awk", "mawk": "awk",
	"sh": "bash", "zsh": "bash", "dash": "bash", "ksh": "bash", "mksh": "bash", "oksh": "bash", "yash": "bash", "gsed": "sed",
	"nixos-rebuild": "darwin-rebuild", "home-manager": "darwin-rebuild", "bunx": "npx", "pnpm dlx": "npx", "yarn dlx": "npx", "bun x": "npx"}

// opts reads a list of options that take one word, or the count after a colon (--option:2)
func opts(words string) map[string]int {
	m := map[string]int{}
	for _, w := range strings.Fields(words) {
		name, n, _ := strings.Cut(w, ":")
		m[name] = 1
		if n == "2" {
			m[name] = 2
		}
	}
	return m
}

func optsFor(grammar string) map[string]int {
	if g, ok := sameOpts[grammar]; ok {
		grammar = g
	}
	return valueOpts[grammar]
}

// an opt is one option as the program reads it, with its value words. word is the index of the word that holds
// the last value, or the option itself when it has none
type opt struct {
	name   string
	values []string
	word   int
}

// args is a command's words split into options and operands. pathspecs are the operands after --
type args struct {
	opts      []opt
	operands  []string
	pathspecs []string
	// end is the index of the first word past the options, when the read stopped at an operand
	end int
}

func (a args) has(names ...string) bool {
	return slices.ContainsFunc(a.opts, func(o opt) bool { return slices.Contains(names, o.name) })
}

// value is the last value of the last of names given
func (a args) value(names ...string) (string, bool) {
	for i := len(a.opts) - 1; i >= 0; i-- {
		if o := a.opts[i]; slices.Contains(names, o.name) && len(o.values) > 0 {
			return o.values[len(o.values)-1], true
		}
	}
	return "", false
}

// parseArgs reads words, those after the program or subcommand, as GNU tools do: options anywhere until --
func parseArgs(grammar string, words []string) args { return readArgs(grammar, words, false, false) }

// leadingArgs reads only the options before the first operand, as a wrapper, a shell, or git's global options do.
// a NAME=value word among them, as env takes, counts with the options
func leadingArgs(grammar string, words []string) args { return readArgs(grammar, words, true, false) }

// readArgs splits a cluster such as -vC dir the way getopt does: letters up to the first that takes a value,
// whose value is the rest of the word or the next words. a shell also takes options that start with +.
// greedy reads an option the grammar does not list as one that takes the next word, which a fail-closed second reading needs
func readArgs(grammar string, words []string, leading, greedy bool) args {
	table := optsFor(grammar)
	plus := slices.Contains(shells, grammar)
	r := args{end: len(words)}
	take := func(name string, n, i int) int {
		o := opt{name: name, word: i}
		for k := 0; k < n && i+1 < len(words); k++ {
			i++
			o.values, o.word = append(o.values, words[i]), i
		}
		r.opts = append(r.opts, o)
		return i
	}
	for i := 0; i < len(words); i++ {
		w := words[i]
		n, listed := table[w]
		switch {
		case w == "--":
			r.pathspecs = words[i+1:]
			r.operands = append(r.operands, r.pathspecs...)
			r.end = min(r.end, i+1)
			return r
		case len(w) < 2 || !(w[0] == '-' || (plus && w[0] == '+')):
			if leading && !envWord.MatchString(w) {
				r.end = i
				r.operands = words[i:]
				return r
			}
			if !leading {
				r.operands = append(r.operands, w)
			}
		case strings.HasPrefix(w, "--"):
			name, value, attached := strings.Cut(w, "=")
			if attached {
				r.opts = append(r.opts, opt{name: name, values: []string{value}, word: i})
			} else if n = table[name]; n > 0 || (greedy && !listed) {
				i = take(name, max(n, 1), i)
			} else {
				r.opts = append(r.opts, opt{name: name, word: i})
			}
		// a single-dash word option such as -arch or -sdk
		case listed && len(w) > 2:
			i = take(w, n, i)
		default:
			for j := 1; j < len(w); j++ {
				name := w[:1] + w[j:j+1]
				n, listed := table[name]
				if n == 0 && !(greedy && !listed && j == len(w)-1) {
					r.opts = append(r.opts, opt{name: name, word: i})
					continue
				}
				if j+1 < len(w) {
					r.opts = append(r.opts, opt{name: name, values: []string{w[j+1:]}, word: i})
				} else {
					i = take(name, max(n, 1), i)
				}
				break
			}
		}
	}
	return r
}
