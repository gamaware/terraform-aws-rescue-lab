# One entry point for every offline check. CI runs `make verify` too, so a green
# local run means a green pipeline. Nothing here calls AWS.

TERRAFORM ?= terraform
TFLINT ?= tflint
CHECKOV ?= checkov
TYPST_PY ?= typst==0.14.1
MOTO ?= moto[server,proxy]==5.2.3
ACTIONLINT_PY ?= actionlint-py==1.7.12.25

TF_ROOTS := before/dev before/prod after/bootstrap after/envs/dev after/envs/prod \
	after/modules/app-storage after/modules/app-storage/examples/basic
SHELL_SCRIPTS := $(wildcard scripts/*.sh scripts/tests/*.sh migration/demo/*.sh .claude/hooks/*.sh)

export TF_IN_AUTOMATION := 1
export TF_INPUT := 0
export CHECKOV TFLINT

.PHONY: verify tools fmt validate test findings plan-gate shell workflows report-check \
	report evidence demo test-live clean help

## verify: every offline check (tools, fmt, validate, test, findings, plan-gate, shell, workflows, report-check)
verify: tools fmt validate test findings plan-gate shell workflows report-check
	@echo "verify: all checks passed"

## tools: fail early if a scanner version differs from the one the evidence was recorded with
tools:
	@$(CHECKOV) --version | grep -qx '3.2.529' || { echo "checkov 3.2.529 required"; exit 1; }
	@$(TFLINT) --version | grep -q 'TFLint version 0.61.0' || { echo "tflint 0.61.0 required"; exit 1; }
	@$(TERRAFORM) version -json | jq -e '.terraform_version | split(".") | (.[0] == "1" and (.[1] | tonumber) >= 10)' \
		>/dev/null || { echo "terraform 1.10 or later required"; exit 1; }
	@echo "pass  tool versions"

## fmt: terraform fmt check across the repository
fmt:
	$(TERRAFORM) fmt -check -recursive -diff

## validate: init without a backend and validate every root, before/ included
validate:
	@for dir in $(TF_ROOTS); do \
		$(TERRAFORM) -chdir="$$dir" init -backend=false >/dev/null || exit 1; \
		out="$$($(TERRAFORM) -chdir="$$dir" validate -no-color 2>&1)" || { echo "$$dir: $$out"; exit 1; }; \
		echo "$$dir: $$out"; \
	done

## test: terraform test with mock_provider for the app-storage module
test:
	$(TERRAFORM) -chdir=after/modules/app-storage init -backend=false >/dev/null
	$(TERRAFORM) -chdir=after/modules/app-storage test

## findings: before/ fails exactly the recorded checks; after/ fails none
findings:
	scripts/check-findings.sh

## plan-gate: the plan JSON gate against its fixtures
plan-gate:
	scripts/tests/test-check-plan.sh

## shell: shellcheck and shellharden on every script
shell:
	shellcheck --severity=warning $(SHELL_SCRIPTS)
	shellharden --check $(SHELL_SCRIPTS)

## workflows: actionlint on the active workflows and on the examples for the client's CI
workflows:
	uvx --from '$(ACTIONLINT_PY)' actionlint .github/workflows/*.yml examples/workflows/*.yml

## report-check: report/REPORT.pdf is byte-identical to a fresh build of report/REPORT.md
report-check:
	uvx --from '$(TYPST_PY)' python scripts/build_report.py --check

## report: rebuild report/REPORT.pdf from report/REPORT.md
report:
	uvx --from '$(TYPST_PY)' python scripts/build_report.py

## evidence: rewrite report/evidence/ from the scanners (review the diff before committing)
evidence:
	scripts/check-findings.sh --update

## demo: replay the prod state migration against moto (starts and stops the emulator)
demo:
	scripts/run-demo.sh

## test-live: apply, assert and destroy the module in a real account (maintainer only, profile dev)
test-live:
	scripts/test-live.sh

## clean: remove local Terraform working directories
clean:
	find . -type d -name .terraform -prune -exec rm -rf {} +

help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
