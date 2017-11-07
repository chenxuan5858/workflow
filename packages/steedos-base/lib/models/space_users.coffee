db.space_users = new Meteor.Collection('space_users')

Meteor.startup ()->

	db.space_users._simpleSchema = new SimpleSchema
		space:
			type: String,
			autoform:
				type: "hidden",
				defaultValue: ->
					return Session.get("spaceId");
		name:
			type: String,
			max: 50,
		email:
			type: String,
			regEx: SimpleSchema.RegEx.Email,
			optional: true
			autoform:
				type: "hidden"
		user:
			type: String,
			optional: true,
			foreign_key: true,
			references:
				collection: 'users',
				key: '_id',
				search_keys: ['username']
			autoform:
				omit: true

		organization:
			type: String,
			optional: true,
			autoform:
				omit: true

		organizations:
			type: [String],
			autoform:
				type: "selectorg"
				multiple: true
				defaultValue: ->
					return []

		manager:
			type: String,
			optional: true,
			autoform:
				type: "selectuser"

		sort_no:
			type: Number,
			optional: true

		user_accepted:
			type: Boolean,
			optional: true,
			autoform:
				defaultValue: true

		invite_state:
			type: String
			optional: true,
			autoform:
				omit: true

		created:
			type: Date,
			optional: true
			autoform:
				omit: true
		created_by:
			type: String,
			optional: true
			autoform:
				omit: true
		modified:
			type: Date,
			optional: true
			autoform:
				omit: true
		modified_by:
			type: String,
			optional: true
			autoform:
				omit: true
		mobile: 
			type: String,
			optional: true,
			autoform:
				type: ->
					return "text"
				readonly: ->
					if Steedos.isPaidSpace()
						return false
					else
						return true
		work_phone:
			type: String,
			optional: true
		position:
			type: String,
			optional: true
		hr:
			type: Object,
			optional: true,
			blackbox: true
			autoform:
				omit: true
		company:
			type: String,
			optional: true


	if Meteor.isClient
		db.space_users._simpleSchema.i18n("space_users")
		db.space_users._sortFunction = (doc1, doc2) ->
			if (doc1.sort_no == doc2.sort_no)
				return doc1.name?.localeCompare(doc2.name)
			else if (doc1.sort_no is undefined)
				return 1
			else if (doc2.sort_no is undefined)
				return -1
			else if (doc1.sort_no > doc2.sort_no)
				return -1
			else
				return 1

		db.space_users.before.find (userId, query, options)->
			if !options
				options = {}
			options.sort = db.space_users._sortFunction

		db.space_users.attachSchema(db.space_users._simpleSchema);

		db.space_users.helpers
			space_name: ->
				space = db.spaces.findOne({_id: this.space});
				return space?.name
			organization_name: ->
				if this.organizations
					organizations = SteedosDataManager.organizationRemote.find({_id: {$in: this.organizations}}, {fields: {fullname: 1}})
					return organizations?.getProperty('fullname').join('<br/>')
				return

	if (Meteor.isServer)
		db.space_users.insertVaildate = (userId, doc) ->
			if !doc.space
				throw new Meteor.Error(400, "space_users_error_space_required");
			if !doc.email and !doc.mobile
				throw new Meteor.Error(400, "contact_need_phone_or_email");
			if doc.email
				if not /^([A-Z0-9\.\-\_\+])*([A-Z0-9\+\-\_])+\@[A-Z0-9]+([\-][A-Z0-9]+)*([\.][A-Z0-9\-]+){1,8}$/i.test(doc.email)
					throw new Meteor.Error(400, "email_format_error");

			# 校验工作区是否存在
			space = db.spaces.findOne(doc.space)
			if !space
				throw new Meteor.Error(400, "space_users_error_space_not_found");

			# 要添加用户，需要至少有一个组织权限
			if space.admins.indexOf(userId) < 0
				isOrgAdmin = Steedos.isOrgAdminByOrgIds doc.organizations,userId
				unless isOrgAdmin
					throw new Meteor.Error(400, "organizations_error_org_admins_only")

			# 检验手机号和邮箱是不是指向同一个用户(只有手机和邮箱都填写的时候才需要校验)
			if doc.email and doc.mobile
				phoneNumber = "+86" + doc.mobile
				userExist = db.users.find({$or: ["emails.address": doc.email, "phone.number": phoneNumber]})
				if userExist.count() > 1
					throw new Meteor.Error(400, "邮箱和手机号不匹配")

			# 检验当前工作区下有没有邮件或手机号重复的成员，禁止重复添加
			if doc.email and doc.mobile
				spaceUserExisted = db.space_users.find({space: doc.space}, $or: [{email: doc.email}, {mobile: doc.mobile}])
				if spaceUserExisted.count() > 0
					throw new Meteor.Error(400, "邮箱或手机号已存在")
			else if doc.email
				spaceUserExisted = db.space_users.find({space: doc.space, email: doc.email})
				if spaceUserExisted.count() > 0
					throw new Meteor.Error(400, "该邮箱已存在")
			else if doc.mobile
				spaceUserExisted = db.space_users.find({space: doc.space, mobile: doc.mobile})
				if spaceUserExisted.count() > 0
					throw new Meteor.Error(400, "该手机号已存在")



		db.space_users.before.insert (userId, doc) ->
			doc.created_by = userId;
			doc.created = new Date();
			doc.modified_by = userId;
			doc.modified = new Date();

			if !doc.space
				throw new Meteor.Error(400, "space_users_error_space_required");

			if !doc.email and !doc.mobile
				throw new Meteor.Error(400, "email_required");

			if doc.email
				if not /^([A-Z0-9\.\-\_\+])*([A-Z0-9\+\-\_])+\@[A-Z0-9]+([\-][A-Z0-9]+)*([\.][A-Z0-9\-]+){1,8}$/i.test(doc.email)
					throw new Meteor.Error(400, "email_format_error");

			# check space exists
			space = db.spaces.findOne(doc.space)
			if !space
				throw new Meteor.Error(400, "space_users_error_space_not_found");

			# only space admin or org admin can insert space_users
			if space.admins.indexOf(userId) < 0
				# 要添加用户，需要至少有一个组织权限
				isOrgAdmin = Steedos.isOrgAdminByOrgIds doc.organizations,userId
				unless isOrgAdmin
					throw new Meteor.Error(400, "organizations_error_org_admins_only")

			creator = db.users.findOne(userId)

			if (!doc.user) && (doc.email || doc.mobile)
				if doc.email && doc.mobile
					phoneNumber = "+86" + doc.mobile
					userObjs = db.users.find({
						$or:[{"emails.address": doc.email}, {"phone.number": phoneNumber}]
					}).fetch()
					if userObjs.length > 1
						throw new Meteor.Error(400,"contact_mail_not_match_phine")
					else
						userObj = userObjs[0]

				else if doc.email
					userObj = db.users.findOne({"emails.address": doc.email})
				else if doc.mobile
					phoneNumber = "+86" + doc.mobile
					userObj = db.users.findOne({"phone.number": phoneNumber})

				if (userObj)
					doc.user = userObj._id
					doc.name = userObj.name
				else
					user = {}
					if !doc.name
						doc.name = doc.email.split('@')[0]

					id = db.users._makeNewID()

					options = 
						name: doc.name
						locale: creator.locale
						spaces_invited: [space._id]
						_id: id
						steedos_id: doc.email || id

					if doc.mobile
						phoneNumber = "+86" + doc.mobile
						phone = 
							number: phoneNumber
							verified: false
							modified: new Date()
						options.phone = phone

					if doc.email
						email = [{address: doc.email, verified: false}]
						options.emails = email

					doc.user = db.users.insert options

			if !doc.user
				throw new Meteor.Error(400, "space_users_error_user_required");

			if !doc.name
				throw new Meteor.Error(400, "space_users_error_name_required");

			if doc.email && doc.mobile
				phoneNumber = "+86" + doc.mobile
				oldUser = db.users.find({
					$or:[{"emails.address": doc.email}, {"phone.number": phoneNumber}]
				}).fetch()
			else if doc.email
				oldUser = db.users.find({"emails.address": doc.email}).fetch()
			else if doc.mobile
				phoneNumber = "+86" + doc.mobile
				oldUser = db.users.find({"phone.number": phoneNumber}).fetch()

			userIds = oldUser.getProperty("_id");

			existed=db.space_users.find
				"user": {$in: userIds},"space":doc.space
			if existed.count()>0
				throw new Meteor.Error(400, "space_users_error_space_users_exists");

			if doc.organizations && doc.organizations.length > 0
				# 如果主组织未设置或设置的值不在doc.organizations内，则自动设置为第一个组织
				unless doc.organizations.includes doc.organization
					doc.organization = doc.organizations[0]

		db.space_users.after.insert (userId, doc) ->
			if doc.organizations
				doc.organizations.forEach (org)->
					organizationObj = db.organizations.findOne(org)
					organizationObj.updateUsers();

			# 邀请老用户到新的工作区或在其他可能增加老用户到新工作区的逻辑中，
			# 需要把users表中的信息同步到新的space_users表中。
			user = db.users.findOne(doc.user, {fields:{name:1, mobile:1, emails: 1, email: 1}})
			unset = {}
			# 同步mobile和email到space_user，没有值的话，就清空space_user的mobile和email字段
			unless user.mobile
				unset.mobile = ""
			unless user.emails
				unset.email = ""
			if !user.email and user.emails
				user.email = user.emails[0].address
			
			delete user._id
			delete user.emails
			if _.isEmpty unset
				db.space_users.direct.update({_id: doc._id}, {$set: user})
			else
				db.space_users.direct.update({_id: doc._id}, {$set: user, $unset: unset})

			db.users_changelogs.direct.insert
				operator: userId
				space: doc.space
				operation: "add"
				user: doc.user
				user_count: db.space_users.find({space: doc.space, user_accepted: true}).count()

		db.space_users.before.update (userId, doc, fieldNames, modifier, options) ->
			modifier.$set = modifier.$set || {};

			# check space exists
			space = db.spaces.findOne(doc.space)
			if !space
				throw new Meteor.Error(400, "space_users_error_space_not_found");

			# only space admin or org admin can update space_users
			if space.admins.indexOf(userId) < 0
				# 要修改用户，需要至少有一个组织权限
				isOrgAdmin = Steedos.isOrgAdminByOrgIds doc.organizations,userId
				unless isOrgAdmin
					throw new Meteor.Error(400, "organizations_error_org_admins_only")

			modifier.$set.modified_by = userId;
			modifier.$set.modified = new Date();

			if modifier.$set.user_accepted != undefined and !modifier.$set.user_accepted
				if space.admins.indexOf(doc.user) > 0 || doc.user == space.owner
					throw new Meteor.Error(400,"organizations_error_can_not_set_checkbox_true")


			if modifier.$set.email
				if modifier.$set.email != doc.email
					throw new Meteor.Error(400, "space_users_error_email_readonly");
			if modifier.$set.space
				if modifier.$set.space != doc.space
					throw new Meteor.Error(400, "space_users_error_space_readonly");
			if modifier.$set.user
				if modifier.$set.user != doc.user
					throw new Meteor.Error(400, "space_users_error_user_readonly");

			if modifier.$set.organizations && modifier.$set.organizations.length > 0
				# 修改所有组织且修改后的组织不包含原主组织，则把主组织自动设置为第一个组织
				unless modifier.$set.organizations.includes doc.organization
					modifier.$set.organization = modifier.$set.organizations[0]

			newMobile = modifier.$set.mobile
			# 当把手机号设置为空值时，newMobile为undefined，modifier.$unset.mobile为空字符串
			isMobileCleared = modifier.$unset?.mobile != undefined
			if  newMobile != doc.mobile
				if newMobile
					if Steedos.isPhoneEnabled()
						# 支持手机号短信相关功能时，不可以直接修改user的mobile字段，因为只有验证通过的时候才能更新user的mobile字段
						# 而用户手机号验证通过后会走db.users.before.update逻辑来把mobile字段同步为phone.number值
						# 系统中除了验证验证码外，所有发送短信相关都是直接用的mobile字段，而不是phone.number字段
						number = "+86" + newMobile
						repeatNumberUser = db.users.findOne({'phone.number':number},{fields:{_id:1,phone:1}})
						if repeatNumberUser
							throw new Meteor.Error(400, "space_users_error_phone_already_existed")

						user_set = {}
						user_set.phone = {}
						# 因为只有验证通过的时候才能更新user的mobile字段，所以这里不可以直接修改user的mobile字段
						# user_set.mobile = newMobile
						# 目前只考虑国内手机
						user_set.phone.number = number
						# 变更手机号设置verified为false，以让用户重新验证手机号
						user_set.phone.verified = false
						user_set.phone.modified = new Date()
						if not _.isEmpty(user_set)
							db.users.direct.update({_id: doc.user}, {$set: user_set})

						# 因为只有验证通过的时候才能更新user的mobile字段，所以这里不可以通过修改user的mobile字段来同步所有工作区的mobile字段
						# 只能通过额外单独更新所有工作区的mobile字段，此时user表中mobile没有变更，也不允许直接变更
						db.space_users.direct.update({user: doc.user}, {$set: {mobile: newMobile}}, {multi: true})

				else if isMobileCleared
					user_unset = {}
					user_unset.phone = ""
					user_unset.mobile = ""
					# 更新users表中的相关字段，不可以用direct.update，因为需要更新所有工作区的相关数据
					db.users.update({_id: doc.user}, {$unset: user_unset})


				if (newMobile or isMobileCleared) and Steedos.isPhoneEnabled()
					# 修改人
					lang = Steedos.locale doc.user,true
					euser = db.users.findOne({_id: userId},{fields: {name: 1}})
					params = {
						name: euser.name,
						number: if newMobile then newMobile else TAPi18n.__('space_users_empty_phone', {}, lang)
					}
					paramString = JSON.stringify(params)
					if doc.mobile
						# 发送手机短信给修改前的手机号
						SMSQueue.send({
							Format: 'JSON',
							Action: 'SingleSendSms',
							ParamString: paramString,
							RecNum: doc.mobile,
							SignName: 'OA系统',
							TemplateCode: 'SMS_67660108',
							msg: TAPi18n.__('sms.chnage_mobile.template', params, lang)
						})
					if newMobile
						# 发送手机短信给修改后的手机号
						SMSQueue.send({
							Format: 'JSON',
							Action: 'SingleSendSms',
							ParamString: paramString,
							RecNum: newMobile,
							SignName: 'OA系统',
							TemplateCode: 'SMS_67660108',
							msg: TAPi18n.__('sms.chnage_mobile.template', params, lang)
						})


		db.space_users.after.update (userId, doc, fieldNames, modifier, options) ->
			modifier.$set = modifier.$set || {};
			modifier.$unset = modifier.$unset || {};

			user_set = {}
			user_unset = {}
			if modifier.$set.name != undefined
				user_set.name = modifier.$set.name

			if modifier.$unset.name != undefined
				user_unset.name = modifier.$unset.name

			# 更新users表中的相关字段
			if not _.isEmpty(user_set)
				# 这里不可以更新mobile字段，因该字段是用于发短信的，只有验证通过后才可以同步
				db.users.update({_id: doc.user}, {$set: user_set})
			if not _.isEmpty(user_unset)
				# 这里需要更新mobile字段，删除mobile字段的相关逻辑在[db.space_users.before.update]中已经有了
				db.users.update({_id: doc.user}, {$unset: user_unset})

			if modifier.$set.mobile
				# 只要管理员改过手机号，那么users.mobile就应该清除，否则该users.mobile可能与其他用户的users.mobile值重复
				# 这时只能单独用direct.update，否则users.update又会进一步把清空后的手机号同步回space_users。
				db.users.direct.update({_id: doc.user}, {$unset: {mobile: 1}})

			if modifier.$set.organizations
				modifier.$set.organizations.forEach (org)->
					organizationObj = db.organizations.findOne(org)
					organizationObj.updateUsers();
			if this.previous.organizations
				this.previous.organizations.forEach (org)->
					organizationObj = db.organizations.findOne(org)
					organizationObj.updateUsers();

			if modifier.$set.hasOwnProperty("user_accepted")
				if this.previous.user_accepted != modifier.$set.user_accepted
					db.users_changelogs.direct.insert
						operator: userId
						space: doc.space
						operation: modifier.$set.user_accepted ? "enable" : "disable"
						user: doc.user
						user_count: db.space_users.find({space: doc.space, user_accepted: true}).count()


		db.space_users.before.remove (userId, doc) ->
			# check space exists
			space = db.spaces.findOne(doc.space)
			if !space
				throw new Meteor.Error(400, "space_users_error_space_not_found");

			# only space admin or org admin can remove space_users
			if space.admins.indexOf(userId) < 0
				# 要删除用户，需要至少有一个组织权限
				isOrgAdmin = Steedos.isOrgAdminByOrgIds doc.organizations,userId
				unless isOrgAdmin
					throw new Meteor.Error(400, "organizations_error_org_admins_only")

			# 不能删除当前工作区的拥有者
			if space.owner == doc.user
				throw new Meteor.Error(400, "space_users_error_remove_space_owner");

			if space.admins.indexOf(doc.user) > 0
				throw new Meteor.Error(400,"space_users_error_remove_space_admins");


		db.space_users.after.remove (userId, doc) ->
			if doc.organizations
				doc.organizations.forEach (org)->
					organizationObj = db.organizations.findOne(org)
					organizationObj.updateUsers();

			db.users_changelogs.direct.insert
				operator: userId
				space: doc.space
				operation: "delete"
				user: doc.user
				user_count: db.space_users.find({space: doc.space, user_accepted: true}).count()

			try
				user = db.users.findOne(doc.user,{fields: {email: 1,name: 1,steedos_id:1}})
				if user.email
					locale = Steedos.locale(doc.user, true)
					space = db.spaces.findOne(doc.space,{fields: {name: 1}})
					subject = TAPi18n.__('space_users_remove_mail_subject', {}, locale)
					content = TAPi18n.__('space_users_remove_mail_content', {
						steedos_id: user.steedos_id
						space_name: space?.name
					}, locale)

					MailQueue.send
						to: user.email
						from: user.name + ' on ' + Meteor.settings.email.from
						subject: subject
						html: content
			catch e
				console.error e.stack


		Meteor.publish 'space_users', (spaceId)->
			unless this.userId
				return this.ready()

			user = db.users.findOne(this.userId);

			selector = {}
			if spaceId
				selector.space = spaceId
			else
				selector.space = {$in: user.spaces()}


			return db.space_users.find(selector)



		Meteor.publish 'my_space_users', ()->
			unless this.userId
				return this.ready()


			return db.space_users.find({user: this.userId})

		Meteor.publish 'my_space_user', (spaceId)->
			unless this.userId
				return this.ready()


			return db.space_users.find({space: spaceId, user: this.userId})

	if Meteor.isServer
		db.space_users._ensureIndex({
			"user": 1
		},{background: true})

		db.space_users._ensureIndex({
			"user_accepted": 1
		},{background: true})

		db.space_users._ensureIndex({
			"space": 1
		},{background: true})

		db.space_users._ensureIndex({
			"is_deleted": 1
		},{background: true})

		db.space_users._ensureIndex({
			"user": 1,
			"user_accepted": 1
		},{background: true})

		db.space_users._ensureIndex({
			"user": 1,
			"space": 1
		},{background: true})

		db.space_users._ensureIndex({
			"space": 1,
			"user_accepted": 1
		},{background: true})

		db.space_users._ensureIndex({
			"space": 1,
			"user": 1,
			"user_accepted": 1
		},{background: true})

		db.space_users._ensureIndex({
			"space": 1,
			"manager": 1
		},{background: true})

		db.space_users._ensureIndex({
			"manager": 1
		},{background: true})

		db.space_users._ensureIndex({
			"space": 1,
			"created": 1
		},{background: true})

		db.space_users._ensureIndex({
			"space": 1,
			"created": 1,
			"modified": 1
		},{background: true})

		db.space_users._ensureIndex({
			"organizations": 1
		},{background: true})

		db.space_users._ensureIndex({
			"mobile": 1
		},{background: true})