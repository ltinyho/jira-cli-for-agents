package cmd

import (
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/spf13/cobra"
)

//go:embed install_skill.sh
var installSkillScript string

var (
	installSkillDir   string
	installSkillLink  bool
	installSkillUninstall bool
)

var installSkillCmd = &cobra.Command{
	Use:   "install-skill",
	Short: "Install the jira-cli skill for OpenCode / Claude Code",
	Long: `Install the jira-cli skill so AI agents (OpenCode, Claude Code) can use
this CLI to interact with westwell-lab's Jira Data Center.

By default, auto-detects the skills directory:
  1. $XDG_CONFIG_HOME/opencode/skills
  2. ~/.config/opencode/skills
  3. ~/.agents/skills
  4. ./.opencode/skills (current project)

Examples:
  # Auto-detect target
  jira-cli install-skill

  # Symlink mode (fork updates auto-apply)
  jira-cli install-skill --link

  # Custom target
  jira-cli install-skill --skills-dir ~/.agents/skills

  # Uninstall
  jira-cli install-skill --uninstall`,
	RunE: runInstallSkill,
}

func init() {
	rootCmd.AddCommand(installSkillCmd)

	installSkillCmd.Flags().StringVar(&installSkillDir, "skills-dir", "",
		"target skills directory (default: auto-detect)")
	installSkillCmd.Flags().BoolVar(&installSkillLink, "link", false,
		"create a symlink instead of copying (auto-updates on fork changes)")
	installSkillCmd.Flags().BoolVar(&installSkillUninstall, "uninstall", false,
		"remove the installed skill")
}

func runInstallSkill(cmd *cobra.Command, args []string) error {
	// Windows 下 bash 不可用，提示用户用 Git Bash 或 WSL
	if runtime.GOOS == "windows" && !hasBash() {
		return fmt.Errorf("install-skill requires bash; please use Git Bash or WSL on Windows")
	}

	// 写入临时文件并执行
	tmpFile, err := os.CreateTemp("", "jira-cli-install-skill-*.sh")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(installSkillScript); err != nil {
		return fmt.Errorf("failed to write script: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp file: %w", err)
	}
	if err := os.Chmod(tmpFile.Name(), 0o755); err != nil {
		return fmt.Errorf("failed to chmod script: %w", err)
	}

	// 构造参数
	var scriptArgs []string
	if installSkillDir != "" {
		scriptArgs = append(scriptArgs, "--skills-dir", installSkillDir)
	}
	if installSkillLink {
		scriptArgs = append(scriptArgs, "--link")
	}
	if installSkillUninstall {
		scriptArgs = append(scriptArgs, "--uninstall")
	}

	// 在当前 shell 用户的 HOME 下执行，让脚本能正确探测 ~/
	home, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()

	execCmd := exec.Command("bash", append([]string{tmpFile.Name()}, scriptArgs...)...)
	execCmd.Dir = cwd
	execCmd.Env = append(os.Environ(), "HOME="+home)
	execCmd.Stdin = os.Stdin
	execCmd.Stdout = os.Stdout
	execCmd.Stderr = os.Stderr

	if err := execCmd.Run(); err != nil {
		return fmt.Errorf("install script failed: %w", err)
	}
	return nil
}

func hasBash() bool {
	_, err := exec.LookPath("bash")
	return err == nil
}

// 确保 filepath 被使用（避免 import error 如果上面没用到）
var _ = filepath.Join
