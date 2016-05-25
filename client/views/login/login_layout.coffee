Template.loginLayout.helpers
                
        urlPrefix: ->
                return __meteor_runtime_config__.ROOT_URL_PATH_PREFIX
                
        isLoggedout: ->
                if Meteor.userId()
                        return false;
                else
                        return true;

Template.loginLayout.onCreated ->
        self = this;

        $(window).resize ->
                $(".content-wrapper").css("min-height", ($(window).height()-50) + "px");


Template.loginLayout.onRendered ->

        $(window).resize();

        if ($("body").hasClass('sidebar-open')) 
                $("body").removeClass('sidebar-open');

Template.loginLayout.events

        'click #btnLogout': (e, t) ->
                FlowRouter.go("/logout")

        'click #btnSignIn': (e, t) ->
                FlowRouter.go("/sign-in")
                
        'click #btnSignUp': (e, t) ->
                FlowRouter.go("/sign-up")