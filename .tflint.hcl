config {
  format           = "compact"
  call_module_type = "local"   # follow ../modules/*; skip registry modules
  # plugin_dir defaults to ~/.tflint.d/plugins; override with
  # TFLINT_PLUGIN_DIR in CI if you cache plugins elsewhere.
}

# Bundled with TFLint; declared explicitly so the preset is a visible choice.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Beyond the preset: these pair well with generated per-stage READMEs.
rule "terraform_documented_variables" { enabled = true }
rule "terraform_documented_outputs"   { enabled = true }
rule "terraform_naming_convention"    { enabled = true }
rule "terraform_unused_declarations"  { enabled = true }
rule "terraform_typed_variables"      { enabled = true }
rule "terraform_required_version"     { enabled = true }
rule "terraform_required_providers"   { enabled = true }

# No provider ruleset exists for bpg/proxmox, so core language checks are
# what runs. Add cloud rulesets (aws/azurerm/google) only if you use them.
