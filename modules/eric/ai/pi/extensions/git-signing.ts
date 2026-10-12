// agent commits sign with ssh-keygen, skipping the 1password prompt
// same override as the GIT_CONFIG_* env in claude/settings.json
export default function () {
  process.env.GIT_CONFIG_COUNT = "1";
  process.env.GIT_CONFIG_KEY_0 = "gpg.ssh.program";
  process.env.GIT_CONFIG_VALUE_0 = "ssh-keygen";
}
