# Terraform plan-time security policies
# Evaluated by Conftest against `terraform show -json tfplan.binary`
package main

import rego.v1

# ---------------------------------------------------------------
# Helper: normalize IAM Action which may be a string or an array
# ---------------------------------------------------------------
as_array(x) := x if is_array(x)

as_array(x) := [x] if not is_array(x)

# Resource changes that are being created or updated (ignore deletes/no-ops)
active_changes contains rc if {
	some rc in input.resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

# ---------------------------------------------------------------
# POLICY 1: No security group ingress open to the world,
# except explicitly allowed public ports (80/443)
# ---------------------------------------------------------------
allowed_public_ports := {80, 443}

deny contains msg if {
	some rc in active_changes
	rc.type == "aws_security_group"
	some rule in rc.change.after.ingress
	some cidr in rule.cidr_blocks
	cidr == "0.0.0.0/0"
	not rule.from_port in allowed_public_ports
	msg := sprintf(
		"%s: ingress rule opens port %d to 0.0.0.0/0 — only ports %v may be world-reachable",
		[rc.address, rule.from_port, allowed_public_ports],
	)
}

# ---------------------------------------------------------------
# POLICY 2: No IAM policy may Allow Action "*"
# ---------------------------------------------------------------
deny contains msg if {
	some rc in active_changes
	rc.type in {"aws_iam_policy", "aws_iam_role_policy", "aws_iam_user_policy", "aws_iam_group_policy"}
	doc := json.unmarshal(rc.change.after.policy)
	some stmt in doc.Statement
	stmt.Effect == "Allow"
	some action in as_array(stmt.Action)
	action == "*"
	msg := sprintf("%s: IAM policy allows Action '*' — enumerate the required actions instead", [rc.address])
}

# ---------------------------------------------------------------
# POLICY 3: EC2 instances must have encrypted root volumes
# ---------------------------------------------------------------
deny contains msg if {
	some rc in active_changes
	rc.type == "aws_instance"
	some rbd in rc.change.after.root_block_device
	rbd.encrypted == false
	msg := sprintf("%s: root block device is not encrypted", [rc.address])
}

# ---------------------------------------------------------------
# POLICY 4: Mandatory tags on core taggable resources
# ---------------------------------------------------------------
required_tags := {"Environment", "ManagedBy"}

tagged_types := {"aws_instance", "aws_s3_bucket", "aws_security_group"}

deny contains msg if {
	some rc in active_changes
	rc.type in tagged_types
	tags := object.get(rc.change.after, "tags", {})
	missing := required_tags - {k | some k, _ in tags}
	count(missing) > 0
	msg := sprintf("%s: missing required tags %v", [rc.address, missing])
}
