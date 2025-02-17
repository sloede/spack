% Copyright 2013-2024 Lawrence Livermore National Security, LLC and other
% Spack Project Developers. See the top-level COPYRIGHT file for details.
%
% SPDX-License-Identifier: (Apache-2.0 OR MIT)

%=============================================================================
% This logic program adds detailed error messages to Spack's concretizer
%
% Note that functions used in rule bodies here need to have a corresponding
% #show line in display.lp, otherwise they won't be passed through to the
% error solve.
%=============================================================================

#program error_messages.

% Create a causal tree between trigger conditions by locating the effect conditions
% that are triggers for another condition. Condition2 is caused by Condition1
condition_cause(Condition2, ID2, Condition1, ID1) :-
  condition_holds(Condition2, node(ID2, Package2)),
  pkg_fact(Package2, condition_trigger(Condition2, Trigger)),
  condition_requirement(Trigger, Name, Package),
  condition_nodes(Trigger, TriggerNode, node(ID, Package)),
  trigger_node(Trigger, TriggerNode, node(ID2, Package2)),
  attr(Name, node(ID, Package)),
  condition_holds(Condition1, node(ID1, Package1)),
  pkg_fact(Package1, condition_effect(Condition1, Effect)),
  imposed_constraint(Effect, Name, Package),
  imposed_nodes(Effect, node(ID1, Package1), node(ID, Package)).

condition_cause(Condition2, ID2, Condition1, ID1) :-
  condition_holds(Condition2, node(ID2, Package2)),
  pkg_fact(Package2, condition_trigger(Condition2, Trigger)),
  condition_requirement(Trigger, Name, Package, A1),
  condition_nodes(Trigger, TriggerNode, node(ID, Package)),
  trigger_node(Trigger, TriggerNode, node(ID2, Package2)),
  attr(Name, node(ID, Package), A1),
  condition_holds(Condition1, node(ID1, Package1)),
  pkg_fact(Package1, condition_effect(Condition1, Effect)),
  imposed_constraint(Effect, Name, Package, A1),
  imposed_nodes(Effect, node(ID1, Package1), node(ID, Package)).

condition_cause(Condition2, ID2, Condition1, ID1) :-
  condition_holds(Condition2, node(ID2, Package2)),
  pkg_fact(Package2, condition_trigger(Condition2, Trigger)),
  condition_requirement(Trigger, Name, Package, A1, A2),
  condition_nodes(Trigger, TriggerNode, node(ID, Package)),
  trigger_node(Trigger, TriggerNode, node(ID2, Package2)),
  attr(Name, node(ID, Package), A1, A2),
  condition_holds(Condition1, node(ID1, Package1)),
  pkg_fact(Package1, condition_effect(Condition1, Effect)),
  imposed_constraint(Effect, Name, Package, A1, A2),
  imposed_nodes(Effect, node(ID1, Package1), node(ID, Package)).

condition_cause(Condition2, ID2, Condition1, ID1) :-
  condition_holds(Condition2, node(ID2, Package2)),
  pkg_fact(Package2, condition_trigger(Condition2, Trigger)),
  condition_requirement(Trigger, Name, Package, A1, A2, A3),
  condition_nodes(Trigger, TriggerNode, node(ID, Package)),
  trigger_node(Trigger, TriggerNode, node(ID2, Package2)),
  attr(Name, node(ID, Package), A1, A2, A3),
  condition_holds(Condition1, node(ID1, Package1)),
  pkg_fact(Package1, condition_effect(Condition1, Effect)),
  imposed_constraint(Effect, Name, Package, A1, A2, A3),
  imposed_nodes(Effect, node(ID1, Package1), node(ID, Package)).

% special condition cause for dependency conditions
% we can't simply impose the existence of the node for dependency conditions
% because we need to allow for the choice of which dupe ID the node gets
condition_cause(Condition2, ID2, Condition1, ID1) :-
  condition_holds(Condition2, node(ID2, Package2)),
  pkg_fact(Package2, condition_trigger(Condition2, Trigger)),
  condition_requirement(Trigger, "node", Package),
  condition_nodes(Trigger, TriggerNode, node(ID, Package)),
  trigger_node(Trigger, TriggerNode, node(ID2, Package2)),
  attr("node", node(ID, Package)),
  condition_holds(Condition1, node(ID1, Package1)),
  pkg_fact(Package1, condition_effect(Condition1, Effect)),
  imposed_constraint(Effect, "dependency_holds", Parent, Package, Type),
  imposed_nodes(Effect, node(ID1, Package1), node(ID, Package)),
  attr("depends_on", node(X, Parent), node(ID, Package), Type).

% The literal startcauses is used to separate the variables that are part of the error from the
% ones describing the causal tree of the error. After startcauses, each successive pair must be
% a condition and a condition_set id for which it holds.

% More specific error message if the version cannot satisfy some constraint
% Otherwise covered by `no_version_error` and `versions_conflict_error`.
error(1, "Cannot satisfy '{0}@{1}'", Package, Constraint, startcauses, ConstraintCause, CauseID)
  :- attr("node_version_satisfies", node(ID, Package), Constraint),
     pkg_fact(TriggerPkg, condition_effect(ConstraintCause, EffectID)),
     imposed_constraint(EffectID, "node_version_satisfies", Package, Constraint),
     condition_holds(ConstraintCause, node(CauseID, TriggerPkg)),
     attr("version", node(ID, Package), Version),
     not pkg_fact(Package, version_satisfies(Constraint, Version)).

error(0, "Cannot satisfy '{0}@{1}' and '{0}@{2}", Package, Constraint1, Constraint2, startcauses, Cause1, C1ID, Cause2, C2ID)
  :- attr("node_version_satisfies", node(ID, Package), Constraint1),
     pkg_fact(TriggerPkg1, condition_effect(Cause1, EffectID1)),
     imposed_constraint(EffectID1, "node_version_satisfies", Package, Constraint1),
     condition_holds(Cause1, node(C1ID, TriggerPkg1)),
     % two constraints
     attr("node_version_satisfies", node(ID, Package), Constraint2),
     pkg_fact(TriggerPkg2, condition_effect(Cause2, EffectID2)),
     imposed_constraint(EffectID2, "node_version_satisfies", Package, Constraint2),
     condition_holds(Cause2, node(C2ID, TriggerPkg2)),
     % version chosen
     attr("version", node(ID, Package), Version),
     % version satisfies one but not the other
     pkg_fact(Package, version_satisfies(Constraint1, Version)),
     not pkg_fact(Package, version_satisfies(Constraint2, Version)).

% causation tracking error for no or multiple virtual providers
error(0, "Cannot find a valid provider for virtual {0}", Virtual, startcauses, Cause, CID)
  :- attr("virtual_node", node(X, Virtual)),
     not provider(_, node(X, Virtual)),
     imposed_constraint(EID, "dependency_holds", Parent, Virtual, Type),
     pkg_fact(TriggerPkg, condition_effect(Cause, EID)),
     condition_holds(Cause, node(CID, TriggerPkg)).

% At most one variant value for single-valued variants
error(0, "'{0}' required multiple values for single-valued variant '{1}'\n    Requested 'Spec({1}={2})' and 'Spec({1}={3})'", Package, Variant, Value1, Value2, startcauses, Cause1, X, Cause2, X)
  :- attr("node", node(X, Package)),
     node_has_variant(node(X, Package), Variant, VariantID),
     variant_single_value(node(X, Package), Variant),
     build(node(X, Package)),
     attr("variant_value", node(X, Package), Variant, Value1),
     imposed_constraint(EID1, "variant_set", Package, Variant, Value1),
     pkg_fact(TriggerPkg1, condition_effect(Cause1, EID1)),
     condition_holds(Cause1, node(X, TriggerPkg1)),
     attr("variant_value", node(X, Package), Variant, Value2),
     imposed_constraint(EID2, "variant_set", Package, Variant, Value2),
     pkg_fact(TriggerPkg2, condition_effect(Cause2, EID2)),
     condition_holds(Cause2, node(X, TriggerPkg2)),
     Value1 < Value2. % see[1] in concretize.lp

% Externals have to specify external conditions
error(0, "Attempted to use external for {0} which does not satisfy any configured external spec version", Package, startcauses, ExternalCause, CID)
  :- external(node(ID, Package)),
     attr("external_spec_selected", node(ID, Package), Index),
     imposed_constraint(EID, "external_conditions_hold", Package, Index),
     pkg_fact(TriggerPkg, condition_effect(ExternalCause, EID)),
     condition_holds(ExternalCause, node(CID, TriggerPkg)),
     not external_version(node(ID, Package), _, _).

error(0, "Attempted to build package {0} which is not buildable and does not have a satisfying external\n        attr('{1}', '{2}') is an external constraint for {0} which was not satisfied", Package, Name, A1)
  :- external(node(ID, Package)),
     not attr("external_conditions_hold", node(ID, Package), _),
     imposed_constraint(EID, "external_conditions_hold", Package, _),
     trigger_and_effect(Package, TID, EID),
     condition_requirement(TID, Name, A1),
     not attr(Name, node(_, A1)).

error(0, "Attempted to build package {0} which is not buildable and does not have a satisfying external\n        attr('{1}', '{2}', '{3}') is an external constraint for {0} which was not satisfied", Package, Name, A1, A2)
  :- external(node(ID, Package)),
     not attr("external_conditions_hold", node(ID, Package), _),
     imposed_constraint(EID, "external_conditions_hold", Package, _),
     trigger_and_effect(Package, TID, EID),
     condition_requirement(TID, Name, A1, A2),
     not attr(Name, node(_, A1), A2).

error(0, "Attempted to build package {0} which is not buildable and does not have a satisfying external\n        attr('{1}', '{2}', '{3}', '{4}') is an external constraint for {0} which was not satisfied", Package, Name, A1, A2, A3)
  :- external(node(ID, Package)),
     not attr("external_conditions_hold", node(ID, Package), _),
     imposed_constraint(EID, "external_conditions_hold", Package, _),
     trigger_and_effect(Package, TID, EID),
     condition_requirement(TID, Name, A1, A2, A3),
     not attr(Name, node(_, A1), A2, A3).

error(0, "Attempted to build package {0} which is not buildable and does not have a satisfying external\n        'Spec({0} {1}={2})' is an external constraint for {0} which was not satisfied\n        'Spec({0} {1}={3})' required", Package, Variant, Value, OtherValue, startcauses, OtherValueCause, CID)
  :- external(node(ID, Package)),
     not attr("external_conditions_hold", node(ID, Package), _),
     imposed_constraint(EID, "external_conditions_hold", Package, _),
     trigger_and_effect(Package, TID, EID),
     condition_requirement(TID, "variant_value", Package, Variant, Value),
     not attr("variant_value", node(ID, Package), Variant, Value),
     attr("variant_value", node(ID, Package), Variant, OtherValue),
     imposed_constraint(EID2, "variant_set", Package, Variant, OtherValue),
     pkg_fact(TriggerPkg, condition_effect(OtherValueCause, EID2)),
     condition_holds(OtherValueCause, node(CID, TriggerPkg)).

error(0, "Attempted to build package {0} which is not buildable and does not have a satisfying external\n        attr('{1}', '{2}', '{3}', '{4}', '{5}') is an external constraint for {0} which was not satisfied", Package, Name, A1, A2, A3, A4)
  :- external(node(ID, Package)),
     not attr("external_conditions_hold", node(ID, Package), _),
     imposed_constraint(EID, "external_conditions_hold", Package, _),
     trigger_and_effect(Package, TID, EID),
     condition_requirement(TID, Name, A1, A2, A3, A4),
     not attr(Name, node(_, A1), A2, A3, A4).

% error message with causes for conflicts
error(0, Msg, startcauses, TriggerID, ID1, ConstraintID, ID2)
  :- attr("node", node(ID, Package)),
     pkg_fact(Package, conflict(TriggerID, ConstraintID, Msg)),
     % node(ID1, TriggerPackage) is node(ID2, Package) in most, but not all, cases
     condition_holds(TriggerID, node(ID1, TriggerPackage)),
     condition_holds(ConstraintID, node(ID2, Package)),
     unification_set(X, node(ID2, Package)),
     unification_set(X, node(ID1, TriggerPackage)),
     not external(node(ID, Package)),  % ignore conflicts for externals
     not attr("hash", node(ID, Package), _).  % ignore conflicts for installed packages

% variables to show
#show error/2.
#show error/3.
#show error/4.
#show error/5.
#show error/6.
#show error/7.
#show error/8.
#show error/9.
#show error/10.
#show error/11.

#show condition_cause/4.
#show condition_reason/2.

% Define all variables used to avoid warnings at runtime when the model doesn't happen to have one
#defined error/2.
#defined error/3.
#defined error/4.
#defined error/5.
#defined error/6.
#defined error/7.
#defined error/8.
#defined error/9.
#defined error/10.
#defined error/11.
#defined attr/2.
#defined attr/3.
#defined attr/4.
#defined attr/5.
#defined pkg_fact/2.
#defined imposed_constraint/3.
#defined imposed_constraint/4.
#defined imposed_constraint/5.
#defined imposed_constraint/6.
#defined condition_cause/4.
#defined condition_requirement/3.
#defined condition_requirement/4.
#defined condition_requirement/5.
#defined condition_requirement/6.
#defined condition_holds/2.
#defined unification_set/2.
#defined external/1.
#defined trigger_and_effect/3.
#defined build/1.
#defined node_has_variant/3.
#defined provider/2.
#defined external_version/3.
#defined variant_single_value/2.
