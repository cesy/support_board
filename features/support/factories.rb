Factory.define :admin do |admin|
  admin.sequence(:login) { |n| "admin-#{n}" }
  admin.password "secret"
  admin.password_confirmation { |a| a.password }
  admin.email { |a| "#{a.login}@ao3.org" }
end

Factory.define :user do |user|
  user.sequence(:id) { |n| n }
  user.sequence(:login) { |n| "testuser#{n}" }
  user.password "secret"
  user.password_confirmation { |u| u.password }
  user.email { |u| "#{u.login}@ao3.org" }
end

Factory.define :pseud do |pseud|
  pseud.name "my test pseud"
  pseud.association :user
end

Factory.define :support_ticket do |support_ticket|
  support_ticket.sequence(:id) { |n| n }
  support_ticket.sequence(:summary) { |n| "support ticket #{n}" }
  support_ticket.email { |u| "guest@ao3.org" unless u.user_id }
end

Factory.define :code_ticket do |code_ticket|
  code_ticket.sequence(:summary) { |n| "code ticket #{n}" }
end

Factory.define :archive_faq do |archive_faq|
  archive_faq.title { |a| "faq #{a.position}" }
  archive_faq.after_build { |archive_faq| archive_faq.user_id = Factory.create(:volunteer)}
end

Factory.define :volunteer, :parent => :user do |volunteer|
  volunteer.after_create { |volunteer| volunteer.support_volunteer = "1" }
end

Factory.define :support_admin, :parent => :user do |admin|
  admin.after_create { |volunteer| volunteer.support_admin = "1" }
end
