Template.relocate_modal.helpers({

    fields: function() {
        return new SimpleSchema({
            relocate_users: {
                autoform: {
                    type: "selectuser"
                },
                optional: true,
                type: String,
                label: TAPi18n.__("Inbox Suggestion NextSteps Handler Label")
            }
        });
    },

    values: function() {
        return {};
    }

})


Template.relocate_modal.events({

    'show.bs.modal #relocate_modal': function(event) {
        // $("#relocate_steps").select2();
        $("#relocate_steps").empty();


        var relocate_users = $("input[name='relocate_users']")[0];

        relocate_users.value = "";
        relocate_users.dataset.values = '';

        var c = InstanceManager.getCurrentStep();

        $("#relocate_currentStepName").html(c.name);

        var ins_steps = WorkflowManager.getInstanceSteps();
        if (ins_steps) {
            ins_steps.forEach(function(s) {
                if (s.id != c.id && s.step_type != "condition") {
                    $("#relocate_steps").append("<option value= '" + s.id + "'> " + s.name + " </option>");
                }
            })
        }

        $("#relocate_steps").val(null);
        $("#relocate_modal_text").val(null);
    },

    'change #relocate_steps': function(event) {
        var v = $("#relocate_steps").val();
        var relocate_users = $("input[name='relocate_users']")[0];
        relocate_users.value = "";
        relocate_users.dataset.values = '';
        if (v) {
            var s = WorkflowManager.getInstanceStep(v);
            if (s.step_type == "start" || s.step_type == "end") {
                $("#relocate_users_p").css("display", "none");
            } else {
                $("#relocate_users_p").css("display", "");
            }

            if (s.step_type == "counterSign") {
                relocate_users.dataset.multiple = true;
            } else {
                relocate_users.dataset.multiple = false;
            }

            var next_step_users = ApproveManager.getNextStepUsers(WorkflowManager.getInstance(), s._id);
            if (!_.isEmpty(next_step_users)) {
                relocate_users.dataset.userOptions = _.pluck(next_step_users, "id");
                relocate_users.dataset.showOrg = false;
            } else {
                delete relocate_users.dataset.userOptions;
                relocate_users.dataset.showOrg = true;
                if (s.deal_type == 'pickupAtRuntime') {
                    var ref, ref1, ref2;
                    relocate_users.dataset.is_within_user_organizations = ((ref = Meteor.settings) != null ? (ref1 = ref["public"]) != null ? (ref2 = ref1.workflow) != null ? ref2.user_selection_within_user_organizations : void 0 : void 0 : void 0) || false;
                }
            }
        } else {
            $("#relocate_users_p").css("display", "");
        }
    },

    'click #relocate_help': function(event, template) {
        Steedos.openWindow(t("relocate_help"));
    },

    'click #relocate_modal_ok': function(event, template) {
        var sv = $("#relocate_steps").val();
        if (!sv) {
            return;
        }

        var reason = $("#relocate_modal_text").val();
        // if (!reason) {
        //     toastr.error(TAPi18n.__('Instance Relocate Hint'));
        //     return;
        // }

        var uv = null;
        var s = WorkflowManager.getInstanceStep(sv);
        if (s.step_type == "start") {
            var instance = WorkflowManager.getInstance();
            if (instance) {
                uv = instance.applicant;
            }
        } else if (s.step_type == "end") {
            uv = null;
        } else {
            uv = AutoForm.getFieldValue("relocate_users", "relocate");
        }

        if (s.step_type != "end" && !uv) {
            toastr.error(TAPi18n.__('Instance Relocate NewInboxUsers'));
            return;
        }

        var user_ids = [];

        if (uv) {
            user_ids = uv.split(",");
        }

        InstanceManager.relocateIns(sv, user_ids, reason);

        Modal.hide(template);
    },

})