class CodeTicket < ActiveRecord::Base

  belongs_to :support_identity # the support identity of the last user to work on the ticket
  belongs_to :code_ticket # for dupes
  belongs_to :release_note # when deployed

  has_many :code_votes # for prioritizing (lots of votes = high priority)
  has_many :code_notifications  # a bunch of email addresses for update notifications
  has_many :code_details  # like comments, except non-threaded and with extra attributes
  has_many :support_tickets  # tickets waiting for this fix
  has_many :code_commits # created from git hub pushes

  ### VALIDATIONS and CALLBACKS

  # must have summary
  validates_presence_of :summary
  validates_length_of :summary, :maximum=> 140 # tweet length!

  attr_accessor :turn_off_notifications
  # add a default set of watchers to new tickets
  # TODO at the moment, this is just the owner
  after_create :add_default_watchers
  def add_default_watchers
    # on create, add owner to the notifications unless indicated otherwise
    self.watch! unless turn_off_notifications == "1"

    # TODO make default groups. e.g. coders, that people can add and remove themselves to
    # so that when tickets are created the notifications are populated with these groups.
    # when someone is added to that group, add them to all tickets
    # this allows people to remove themselves from individual tickets if they usually watch all
    # and add themselves to individual tickets if they usually don't watch all
  end

  ### HELPER METHODS

  # used in lists
  def name
    "Code Ticket #" + self.id.to_s
  end

  def status_line
    if self.unowned? || self.support_identity_id.blank?
      "open"
    elsif self.code_ticket_id
      "closed as duplicate by #{self.support_identity.byline}"
    elsif self.release_note_id
      "deployed in #{self.release_note.release} (verified by #{self.support_identity.byline})"
    elsif self.staged?
      "waiting for verification (commited by #{self.support_identity.byline})"
    else
      "#{self.status} by #{self.support_identity.byline}"
    end
  end

  # only logged in users can watch code tickets
  def watched?
    raise "Couldn't check watch status. Not logged in." unless User.current_user
    self.code_notifications.where(:email => User.current_user.email).first
  end

  # only logged in users can vote for code tickets and only once
  def voted?
    raise "Couldn't check vote. Not logged in." unless User.current_user
    self.code_votes.where(:user_id => User.current_user.id).first
  end

  def vote_count
    code_votes.sum(:vote)
  end

  # test if ticket is one I can steal (used in volunteer views)
  def stealable?
    raise SecurityError, "Couldn't check stealable. Not logged in." unless User.current_user
    self.support_identity_id != User.current_user.support_identity_id &&
      self.current_state.events.include?(:steal)
  end

  # returns an array of email addresses. [] if none
  def mail_to(private = false)
    notifications = self.code_notifications
    notifications = notifications.official if private
    notifications.map(&:email).uniq
  end

  # okay until we need to paginate
  def self.sort_by_vote
    self.all.sort{|f1,f2|f2.vote_count <=> f1.vote_count}
  end

  ### FILTER
  def self.filter(params = {})
    tickets = CodeTicket.scoped

    # tickets I am watching, private
    if !params[:watching].blank?
      user = User.current_user
      raise SecurityError unless user
      tickets = tickets.joins(:code_notifications) & CodeNotification.where(:email => user.email)
    end

    # ticket's commented on by user
    if !params[:comments_by_support_identity].blank?
      support_identity = SupportIdentity.find_by_name(params[:comments_by_support_identity])
      raise ActiveRecord::RecordNotFound unless support_identity
      tickets = tickets.joins(:code_details) & CodeDetail.public_comments.where(:support_identity_id => support_identity.id)
    end

    # tickets owned by volunteer
    if !params[:owned_by_support_identity].blank?
      support_identity = SupportIdentity.find_by_name(params[:owned_by_support_identity])
      raise ActiveRecord::RecordNotFound unless support_identity
      tickets = tickets.where(:support_identity_id => support_identity.id)
    end

    if !params[:closed_in_release].blank?
      tickets = tickets.where(:release_note_id => params[:closed_in_release])
      # elsif filter by status because the status must be closed even if they forgot to select it
    elsif !params[:status].blank?
      case params[:status]
      when "unowned"
        tickets = tickets.unowned
      when "taken"
        tickets = tickets.taken
      when "committed"
        tickets = tickets.committed
      when "staged"
        tickets = tickets.staged
      when "verified"
        tickets = tickets.verified
      when "closed"
        tickets = tickets.closed
      when "all"
        # no op
      when "open"
        tickets = tickets.where('status != "closed"')
      else
        raise TypeError
      end
    else # default status is not closed (open)
      tickets = tickets.where('status != "closed"')
    end

    # has to come last because sort_by_vote returns an array
    case params[:sort_by]
    when "recently updated"
      tickets = tickets.order("updated_at desc")
    when "least recently updated"
      tickets = tickets.order("updated_at asc")
    when "oldest first"
      tickets = tickets.order("id asc")
    when "by vote"
      tickets = tickets.sort_by_vote
    else # "newest" by default
      tickets = tickets.order("id desc")
    end

    return tickets
  end

  # WORKFLOW / STATE MACHINE
  include Workflow
  workflow_column :status

  workflow do
    state :unowned do
      event :take, :transitions_to => :taken
      event :duplicate, :transitions_to => :closed
      event :commit, :transitions_to => :committed
      event :reject, :transitions_to => :closed
    end
    state :taken do
      event :commit, :transitions_to => :committed
      event :duplicate, :transitions_to => :closed
      event :reject, :transitions_to => :closed
      event :steal, :transitions_to => :taken
      event :reopen, :transitions_to => :unowned
    end
    state :committed do
      event :duplicate, :transitions_to => :closed
      event :stage, :transitions_to => :staged
      event :reopen, :transitions_to => :unowned
    end
    state :staged do
      event :verify, :transitions_to => :verified
      event :reopen, :transitions_to => :unowned
    end
    state :verified do
      event :deploy, :transitions_to => :closed
      event :reopen, :transitions_to => :unowned
    end
    state :closed do
      event :reopen, :transitions_to => :unowned
    end

    on_transition do |from, to, triggering_event, *event_args|
      halt! unless User.current_user.support_volunteer?
      content = "#{from} -> #{to}"
      content += " (#{event_args.first})" unless event_args.blank?
      self.code_details.create(:content => content,
                               :support_identity_id => User.current_user.support_identity_id,
                               :system_log => true)
      # TODO FIXME: sends notifications with ticket in previous state
      self.send_update_notifications unless [:steal].include?(triggering_event)
    end
  end

  ### SCOPES and ARRAYS

  # scopes based on workflow states
  self.workflow_spec.state_names.each do |state|
    scope state, :conditions => { :status => state.to_s }
  end


  def self.not_closed
    where('status != "closed"')
  end

  # tickets which can be used for code commit matching
  # once a code ticket has been staged it's being tested, and you can't add more commits to it
  def self.for_matching
-    where('status != "closed"').where('status != "verified"').where('status != "staged"')
  end

  # returns an array of support ticket ids
  def self.ids
    select("code_tickets.id").map(&:id)
  end

  ### WORKFLOW methods (call with ! to change state)
  # volunteer status is checked by workflow on_transition
  # logs system_log details via workflow on_transition
  # sends notifications via workflow on_transition
  # some methods add you as watcher, some don't. some change owner, some don't

  def take
    self.support_identity_id = User.current_user.support_identity_id
    self.watch! unless self.watched?
  end

  def duplicate(original_id)
    CodeTicket.find original_id # will raise error if no such ticket
    self.code_ticket_id = original_id
    self.support_tickets.update_all(:code_ticket_id => original_id)
    # it's okay if there are duplicates. mail_to uses uniq. and unwatch uses destroy all
    self.code_notifications.update_all(:code_ticket_id => original_id)
    # probably should remove duplicates, but a couple extra votes doesn't hurt
    self.code_votes.update_all(:code_ticket_id => original_id)
    self.support_identity_id = User.current_user.support_identity_id
  end

  def commit(code_commit_id)
    cc = CodeCommit.find(code_commit_id) # will raise unless exists
    raise "code commit already used" if cc.code_ticket_id
    self.support_identity_id = cc.support_identity_id
    cc.code_ticket_id = self.id
    cc.status = "matched"
    cc.save!
  end

  def reject(reason)
    raise "Couldn't reject. No reason given." if reason.blank?
    raise "Couldn't reject. Not support admin." unless User.current_user.support_admin?
    self.support_identity_id = User.current_user.support_identity_id
    self.watch! unless self.watched?
  end

  def steal
    self.send_steal_notification(User.current_user)
    self.support_identity_id = User.current_user.support_identity_id
    self.watch! unless self.watched?
  end

  def reopen(reason)
    raise "Couldn't reopen. No reason given." if reason.blank?
    self.code_ticket_id = nil
    self.release_note_id = nil
    self.support_identity_id = nil
  end

  # don't update support identity, still belongs to committer
  def stage
    self.code_commits.each {|cc| cc.stage!}
  end

  def verify
    raise "Couldn't verify. Not logged in." unless User.current_user
    raise "Couldn't verify. Not support volunteer." unless User.current_user.support_volunteer?
    raise "Couldn't verify, same person committed" unless User.current_user.support_identity != self.support_identity
    self.code_commits.each {|cc| cc.verify!}
    self.support_identity_id = User.current_user.support_identity_id
    self.watch! unless self.watched?
  end

  def deploy(release_note_id)
    note = ReleaseNote.find(release_note_id) # will raise error if no release note
    self.release_note_id = release_note_id
    self.code_commits.each {|cc| cc.deploy!}
    self.support_tickets.each {|st| st.deploy!}
  end

  ### META-WORKFLOW
  # admins can change state for multiple tickets at the same time

  # deploy to stage. all commits must be matched
  def self.stage!
    raise "Couldn't stage. Not logged in." unless User.current_user
    raise "Couldn't stage. Not logged in as support admin." unless User.current_user.support_admin?
    raise "Couldn't stage. Not all commits matched" if CodeCommit.unmatched.count > 0
    CodeCommit.matched.each { |cc| cc.code_ticket.stage! }
  end

  # deploy to production. all tickets must be verified
  # a release note must exist and will be posted
  def self.deploy!(release_note_id)
    raise "Couldn't deploy. Not logged in." unless User.current_user
    raise "Couldn't deploy. Not logged in as support admin." unless User.current_user.support_admin?
    note = ReleaseNote.find_by_id(release_note_id)
    raise "Couldn't deploy. Not all tickets verified" if CodeCommit.staged.count > 0
    raise "Couldn't deploy. Release not doesn't exist." unless User.current_user.support_admin?
    CodeCommit.verified.each {|cc| cc.code_ticket.deploy!(release_note_id)}
    note.update_attribute(:posted, true)
    return note
  end

  ### NON-WORKFLOW but similar methods.
  # call mailers directly to get notifications.
  # call log! directly to add transitions to details
  # check volunteer status directly when necessary

  # user votes
  def vote!(count = 1)
    raise "can't vote for a duplicate" if self.code_ticket_id
    raise "Couldn't vote. Not logged in." unless User.current_user
    raise "already voted" if voted?
    self.code_votes.create(:user => User.current_user, :vote => count)
  end

  # editing a code ticket. volunteers only
  def update_from_edit!(summary, url, browser)
    raise "Couldn't update. Not logged in." unless User.current_user
    raise "Couldn't update. Not support volunteer." unless User.current_user.support_volunteer?
    self.summary = summary
    self.url = url
    self.browser = browser
    self.save!
    self.code_details.create(:content => "ticket edited",
                             :support_identity_id => User.current_user.support_identity_id,
                             :support_response => true,
                             :system_log => true)
    self.send_update_notifications
  end

  # only logged in users can comment
  # only support volunteers can comment on non-open tickets
  def comment!(content, official_comment=true, private_comment = false)
    raise "Couldn't comment. Not logged in." unless User.current_user
    support_response = (official_comment && User.current_user.support_volunteer?)
    raise ArgumentError, "Only official comments can be private" if private_comment && !support_response
    if self.unowned? || support_response
      self.code_details.create(:content => content,
                               :support_identity_id => User.current_user.support_identity.id,
                               :support_response => support_response,
                               :system_log => false,
                               :private => private_comment)
      self.send_update_notifications(private_comment)
    else
      raise "Couldn't comment. Only official comments allowed."
    end
  end

  # only logged in users can watch
  def watch!
    raise "can't watch a duplicate" if self.code_ticket_id
    raise "Couldn't watch. Not logged in." unless User.current_user
    return true if watched?
    self.code_notifications.create(:email => User.current_user.email)
  end

  def unwatch!
    raise "Couldn't remove watch. Not watching." unless watched?
    self.code_notifications.where(:email => User.current_user.email).destroy_all
  end

  ### SEND NOTIFICATIONS

  def send_create_notifications
    self.mail_to.each do |recipient|
      CodeTicketMailer.create_notification(self, recipient).deliver
    end
  end

  def send_update_notifications(private = false)
    self.mail_to(private).each do |recipient|
      CodeTicketMailer.update_notification(self, recipient).deliver
    end
  end

  def send_steal_notification(stealer)
    CodeTicketMailer.steal_notification(self, stealer).deliver
  end

  # SANITIZER stuff

  attr_protected :summary_sanitizer_version
  def sanitized_summary
    # FIXME add sanitizer library and change sanitized_summary to summary in views
    #sanitize_field self, :summary
    summary.html_safe
  end

end
