Template.flow_list_modal.helpers({

});

Template.flow_list_modal.events({
  'shown.bs.modal #flow_list_modal': function(event) {
    var categories, data, forms;
    data = [];
    categories = WorkflowManager.getSpaceCategories();
    flow_id = Session.get("flowId");
    categories.forEach(function(cat) {
      var o;
      o = {};
      o.text = cat.name;
      o.nodes = [];
      o.selectable = false;
      o.state = {
        expanded: true
      };
      forms = db.forms.find({
        category: cat._id
      });
      forms.forEach(function(f) {
        db.flows.find({
          form: f._id,
          state: "enabled"
        }).forEach(function(fl) {
          if (flow_id == fl._id) {
            o.nodes.push({
              text: fl.name,
              flow_id: fl._id,
              state: {selected: true}
            });
          }
          else {
            o.nodes.push({
              text: fl.name,
              flow_id: fl._id
            });
          }
            
        });
      });
      data.push(o);
    });
    forms = db.forms.find({
      category: {
        $in: [null, ""]
      }
    });
    forms.forEach(function(f) {
      db.flows.find({
        form: f._id,
        state: "enabled"
      }).forEach(function(fl) {
        if (flow_id == fl._id) {
          data.push({
            text: fl.name,
            flow_id: fl._id,
            state: {selected: true}
          });
        }
        else {
          data.push({
            text: fl.name,
            flow_id: fl._id
          });
        }
      });
    });

    if (Session.get('flow_list_modal_type') == "create") {
      $('#tree').treeview({
        data: data
      });
      $('#tree').on('nodeSelected', function(event, data) {
        Modal.hide('flow_list_modal');
        InstanceManager.newIns(data.flow_id);
      });
    }
    else if (Session.get('flow_list_modal_type') == "show") {
      $('#tree').treeview({
        data: [{text:TAPi18n.__('All flows'), nodes:data}]
      });
      $('#tree').on('nodeSelected', function(event, data) {
        if (data.flow_id) {
          Session.set("flowId", data.flow_id);  
        }
        else {
          Session.set("flowId", undefined);
        }
        Modal.hide('flow_list_modal');
      });
    }
      
  },


})
