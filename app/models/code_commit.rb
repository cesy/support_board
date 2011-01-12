class CodeCommit < ActiveRecord::Base
  belongs_to :code_ticket
  belongs_to :support_identity

  validates_presence_of :author

  def name
    "#{self.id} by #{self.support_identity.name}"
  end

  before_create :find_support_identity
  def find_support_identity
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
      if self.support_identity.user
        User.current_user = self.support_identity.user
      else
        User.current_user = Role.find_by_name("support_admin").users.first
      end
      ticket.commit!(self.id) if ticket
    end
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

end
