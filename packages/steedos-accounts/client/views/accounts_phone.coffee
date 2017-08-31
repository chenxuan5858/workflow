Template.accounts_phone.helpers
	currentPhoneNumber: ->
		return Accounts.getPhoneNumber()
	title: ->
		if Meteor.userId()
			# 设置密码路由单独设置标题
			isSetupPassword = /\/setup\/password\b/.test(FlowRouter.current().path)
			if isSetupPassword
				return t "accounts_phone_password_title"
			else
				return t "accounts_phone_title"
		else
			return t "steedos_phone_title"
	isBackButtonNeeded: ->
		return Steedos.isAndroidOrIOS() || !Meteor.userId()
	isSetupPassword: ->
		return /\/setup\/password\b/.test(FlowRouter.current().path)
		

Template.accounts_phone.onRendered ->

Template.accounts_phone.events
	'click .btn-send-code': (event,template) ->
		isSetupPassword = /\/setup\/password\b/.test(FlowRouter.current().path)
		unless isSetupPassword
			number = $("input.accounts-phone-number").val()
		else
			number = $(".accounts-phone-number").text()
		unless number
			toastr.error t "accounts_phone_enter_phone_number"
			return

		number = "+86 #{number}"

		swal {
			title: t("accounts_phone_swal_confirm_title"),
			text: t("accounts_phone_swal_confirm_text",number),
			confirmButtonColor: "#DD6B55",
			confirmButtonText: t('OK'),
			cancelButtonText: t('Cancel'),
			showCancelButton: true,
			closeOnConfirm: false
		}, (reason) ->
			# 用户选择取消
			if (reason == false)
				return false;
			$(document.body).addClass('loading')
			unless Meteor.userId()
				checkVerified = true
			Accounts.requestPhoneVerification number, checkVerified, (error)->
				$(document.body).removeClass('loading')
				if error
					toastr.error t(error.reason)
					console.log error
					return
				if Meteor.userId()
					if isSetupPassword
						FlowRouter.go "/accounts/setup/password/code"
					else
						FlowRouter.go "/accounts/setup/phone/#{encodeURIComponent(number)}"
				else
					FlowRouter.go "/steedos/setup/phone/#{encodeURIComponent(number)}"
			sweetAlert.close();

	'click .btn-back': (event,template) ->
		if /steedos\/setup\/phone/.test(FlowRouter.current().path)
			# 手机号登录界面可能会从验证码输入界面返回过来，即oldRoute可能是验证码输入界面
			# 所以这里不可以直接FlowRouter.go oldPath
			FlowRouter.go "steedos/sign-in"
		history.back()

		# oldPath = FlowRouter.current().oldRoute?.path
		# if oldPath
		# 	FlowRouter.go oldPath
		# else
		# 	FlowRouter.go "/steedos/admin"

	'click .btn-close': (event,template) ->
		window.close()


