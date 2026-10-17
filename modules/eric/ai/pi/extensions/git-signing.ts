// agent commits sign with ssh-keygen and agent pushes use the on-disk keys, skipping the 1password prompt
// same override as the GIT_CONFIG_* env in claude/settings.json
export default function () {
  process.env.GIT_CONFIG_COUNT = "2";
  process.env.GIT_CONFIG_KEY_0 = "gpg.ssh.program";
  process.env.GIT_CONFIG_VALUE_0 = "ssh-keygen";
  process.env.GIT_CONFIG_KEY_1 = "core.sshCommand";
  process.env.GIT_CONFIG_VALUE_1 =
    "ssh -o IdentityAgent=none -i ~/.ssh/id_ed25519_github_erics118 -i ~/.ssh/id_ed25519_cornell";
}
