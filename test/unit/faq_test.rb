require 'test_helper'

class FaqTest < ActiveSupport::TestCase
  test "name" do
    assert_equal "1: where to find salt", Faq.find(1).name
    assert_equal "2: why we don't have enough ZPMs", Faq.find(2).name
  end
  test "normal flow" do
    assert_equal "rfc", Faq.find(2).status
    assert_equal "faq", Faq.find(1).status
  end
  test "reopen" do
    reason = "there seems to be some confusion about this"
    faq = Faq.find(1)
    sam = User.find_by_login("sam")
    User.current_user = sam
    assert faq.open_for_comments!(reason)
    assert_equal "rfc", faq.status
    assert_equal %Q{faq -> rfc (#{reason})}, faq.faq_details.last.content
    assert_equal sam.support_identity_id, faq.support_identity_id
  end
  test "post" do
    faq = Faq.find(2)
    User.current_user = User.find_by_login("sam")
    assert_raise(RuntimeError) { faq.post! }
    bofh = User.find_by_login("bofh")
    User.current_user = bofh
    assert faq.post!
    assert_equal "faq", faq.status
    assert_equal %Q{rfc -> faq}, faq.faq_details.last.content
    assert_equal bofh.support_identity_id, faq.support_identity_id
  end
  test "scopes" do
    assert_equal 3, Faq.faq.count
    assert_equal 2, Faq.rfc.count
  end
  test "vote" do
    faq = Faq.find(1)
    User.current_user = nil
    assert faq.vote!
    assert_equal 1, faq.vote_count
    User.current_user = User.find_by_login("dean")
    assert faq.vote!
    assert faq.vote!
    assert_equal 3, faq.vote_count
    User.current_user = User.find_by_login("john")
    assert faq.vote!
    assert_equal 4, faq.vote_count
  end
  test "indirect votes new faq" do
    support_ticket = SupportTicket.find(1)
    User.current_user = User.find_by_login("sam")
    assert faq = support_ticket.answer!
    assert_equal 1, faq.vote_count
  end
  test "indirect votes old faq" do
    support_ticket = SupportTicket.find(1)
    faq = Faq.find(1)
    assert_equal 0, faq.vote_count
    User.current_user = User.find_by_login("sam")
    assert faq = support_ticket.answer!(faq.id)
    assert_equal 1, faq.vote_count
  end
  test "watch" do
    faq = Faq.find(1)
    User.current_user = nil
    assert_raise(RuntimeError) { faq.watch! }
    assert_equal 0, faq.mail_to.size
    User.current_user = User.find_by_login("dean")
    assert_raise(RuntimeError) { faq.unwatch! }
    assert faq.watch!
    assert_raise(RuntimeError) { faq.watch! }
    assert_equal 1, faq.mail_to.size
    User.current_user = User.find_by_login("john")
    assert_nil faq.watched?
    assert faq.watch!
    assert_equal 2, faq.mail_to.size
    assert faq.unwatch!
    assert_equal 1, faq.reload.mail_to.size
    assert_nil faq.watched?
  end
  test "watch by guest" do
    support_ticket = SupportTicket.first
    faq = Faq.find(1)
    User.current_user = User.find_by_login("sam")
    assert faq = support_ticket.answer!(faq.id)
    assert_raise(RuntimeError) { faq.watch!("randomstring") }
    assert_equal 0, faq.mail_to.size
    assert faq.watch!(support_ticket.authentication_code)
    assert_equal 1, faq.mail_to.size
    assert faq.watched?(support_ticket.authentication_code)
    assert_raise(RuntimeError) { faq.unwatch!("randomstring") }
    assert faq.unwatch!(support_ticket.authentication_code)
    assert_nil faq.watched?(support_ticket.authentication_code)
    assert_equal 0, faq.reload.mail_to.size
  end
  test "comment on rfc" do
    faq = Faq.find(2)
    User.current_user = nil
    assert_raise(RuntimeError) { faq.comment!("something") }
    assert_equal 0, faq.faq_details.count
    User.current_user = User.find_by_login("dean")
    assert faq.comment!("user")
    assert_equal 1, faq.faq_details.count
    assert_match "dean wrote", faq.faq_details.first.byline
    assert_equal "user", faq.faq_details.first.content
    User.current_user = User.find_by_login("sam")
    assert faq.comment!("volunteer")
    assert_equal 2, faq.faq_details.count
    assert_match "sam (volunteer) wrote", faq.faq_details.last.byline
    assert_equal "volunteer", faq.faq_details.last.content
    assert faq.comment!("unofficial volunteer", false)
    assert_equal 3, faq.faq_details.count
    assert_match "sam wrote", faq.faq_details.last.byline
    assert_equal "unofficial volunteer", faq.faq_details.last.content
  end
  test "comment on faq" do
    faq = Faq.find(1)
    User.current_user = User.find_by_login("dean")
    assert_raise(RuntimeError) { faq.comment!("something") }
    User.current_user = User.find_by_login("sam")
    assert_raise(RuntimeError) { faq.comment!("something") }
    User.current_user = User.find_by_login("bofh")
    assert_raise(RuntimeError) { faq.comment!("something") }
  end
end