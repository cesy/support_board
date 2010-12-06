# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)
# users
dean = User.create(:login => "dean", :email => "dean@ao3.org",
  :password => "secret", :password_confirmation => "secret")
john = User.create(:login => "john", :email => "john@ao3.org",
  :password => "secret", :password_confirmation => "secret")

# support volunteers
sam = User.create(:login => "sam", :email => "sam@ao3.org",
  :password => "secret", :password_confirmation => "secret")
sam.support_volunteer = "1"
sam.pseuds.create(:name => "sammy", :support_volunteer => true)
rodney = User.create(:login => "rodney", :email => "rodney@ao3.org",
  :password => "secret", :password_confirmation => "secret")
rodney.support_volunteer = "1"
rodney.pseuds.create(:name => "3Phds", :support_volunteer => true)

# code tickets
CodeTicket.create(:summary => "save the world", :pseud_id => sam.support_pseud.id)
CodeTicket.create(:summary => "build a zpm", :pseud_id => rodney.support_pseud.id)
dada = CodeTicket.create(:summary => "repeal DADA")

# support tickets
SupportTicket.create(:summary => "some problem", :email => "guest@ao3.org", :problem => true)
SupportTicket.create(:summary => "a personal problem", :email => "guest@ao3.org", :private => true)
SupportTicket.create(:summary => "where's the salt?", :user_id => dean.id, :question => true)
SupportTicket.create(:summary => "repeal DADA", :user_id => john.id, :private =>true, :code_ticket_id => dada.id)
SupportTicket.create(:summary => "what's my password?", :user_id => john.id, :private =>true, :display_user_name => true)

