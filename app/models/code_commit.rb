class CodeCommit < ActiveRecord::Base
  belongs_to :code_ticket
  belongs_to :support_identity

  validates_presence_of :author

  def name
    "Code Commit ##{self.id}"
  end

  def byline
    self.support_identity.byline
  end

  before_create :ensure_support_identity
  def ensure_support_identity
    identity = SupportIdentity.find_by_name(self.author)
    identity = SupportIdentity.create(:name => self.author) unless identity
    self.support_identity = identity
  end

  after_create :match_to_code_ticket
  def match_to_code_ticket
    return unless self.message
    match = self.message.match /issue (\d+)/
    if match
      ticket = CodeTicket.find_by_id(match[1])
      return unless ticket
      user = self.support_identity.user || ticket.support_identity.try(:user)
      if user
        User.current_user = user
        self.match!(ticket.id)
      end
    end
  end

  # filter code commits
  def self.filter(params = {})
    commits = CodeCommit.scoped

    # commits owned by volunteer
    if !params[:owned_by_support_identity].blank?
      support_identity = SupportIdentity.find_by_name(params[:owned_by_support_identity])
      raise ActiveRecord::RecordNotFound unless support_identity
      commits = commits.where(:support_identity_id => support_identity.id)
    end

    # filter by status
    if !params[:status].blank?
      case params[:status]
      when "unmatched"
        commits = commits.unmatched
      when "matched"
        commits = commits.matched
      when "staged"
        commits = commits.staged
      when "verified"
        commits = commits.verified
      when "deployed"
        commits = commits.deployed
      when "all"
        # no op
      else
        raise TypeError
      end
    else # default status is unmatched
      commits = commits.unmatched
    end

    return commits
  end

  # STATUS/RESOLUTION stuff
  include Workflow
  workflow_column :status

  workflow do
    state :unmatched do
      event :match, :transitions_to => :matched
    end
    state :matched do
      event :unmatch, :transitions_to => :unmatched
      event :stage, :transitions_to => :staged
    end
    state :staged do
      event :unmatch, :transitions_to => :unmatched
      event :verify, :transitions_to => :verified
    end
    state :verified do
      event :deploy, :transitions_to => :deployed
    end
    state :deployed
  end

  self.workflow_spec.state_names.each do |state|
    scope state, :conditions => { :status => state.to_s }
  end

  def match(code_ticket_id)
    ticket = CodeTicket.find code_ticket_id
    # if this code ticket can commit the ticket, commit the ticket
    if ticket.current_state.events[:commit]
      ticket.commit!(self.id)
    else # otherwise, just create the link
      self.code_ticket_id = ticket.id
    end
  end

  def unmatch
    ticket = CodeTicket.find self.code_ticket_id
    # if the ticket was committed on the basis of this one commit, reopen it
    if ticket.code_commits == [self] && ticket.committed?
      ticket.reopen!("unmatched from code commit")
    end
    self.code_ticket_id = nil
  end


end
