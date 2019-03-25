require File.expand_path("../../test_helper", __FILE__)

class JournalChangeNotifierTest < Redmine::ControllerTest
  tests :journals

  fixtures :enabled_modules
  fixtures :email_addresses
  fixtures :issues
  fixtures :issue_statuses
  fixtures :journal_details
  fixtures :journals
  fixtures :projects
  fixtures :projects_trackers
  fixtures :roles
  fixtures :trackers
  fixtures :users

  def setup
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
  end

  def test_update
    post(:update,
         :params => {
           :id => 2,
           :journal => {
             :notes => 'Updated notes'
           }
         },
         :xhr => true)
    assert_equal([
                   200,
                   [
                     text_mail,
                     html_mail,
                   ],
                 ],
                 [
                   @response.status,
                   extract_body(ActionMailer::Base.deliveries.last),
                 ])
  end

  def extract_body(mail)
    return nil if mail.nil?
    mail.body.parts.collect(&:to_s)
  end

  def text_mail
    <<-TEXT_MAIL.gsub(/\n/, "\r\n")
Content-Type: text/plain;
 charset=UTF-8
Content-Transfer-Encoding: 7bit

Issue #1 has been updated by Redmine Admin.

============================================================

@@ -1,2 +1,2 @@
-Some notes with Redmine links: #2, r2.
+Updated notes

============================================================

----------------------------------------
Bug #1: Cannot print recipes
http://localhost:3000/issues/1#change-2

* Author: John Smith
* Status: New
* Priority: 
* Assignee: 
* Category: 
* Target version: 
----------------------------------------
Unable to print recipes



-- 
You have received this notification because you have either subscribed to it, or are involved in it.
To change your notification preferences, please click here: http://hostname/my/account
    TEXT_MAIL
  end

  def html_mail
    <<-HTML_MAIL.gsub(/\n/, "\r\n")
Content-Type: text/html;
 charset=UTF-8
Content-Transfer-Encoding: 7bit

<!DOCTYPE html>
<html>
<head>

<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><style>a:link{color:#169}
a:visited{color:#169}
a:hover{color:#c61a1a}
a:active{color:#c61a1a}</style></head>
<body style="font-family:Verdana, sans-serif;font-size:14px;line-height:1.4em;color:#222">
Issue #1 has been updated by Redmine Admin.

<hr style="width:100%;height:1px;background:#ccc;border:0;margin:1.2em 0">
<pre style='font-family:Consolas, Menlo, "Liberation Mono", Courier, monospace;margin:1em 1em 1em 1.6em;padding:8px;background-color:#fafafa;border:1px solid #e2e2e2;border-radius:3px;width:auto;overflow-x:auto;overflow-y:hidden'>
@@ -1,2 +1,2 @@
-Some notes with Redmine links: #2, r2.
+Updated notes
</pre>
<hr style="width:100%;height:1px;background:#ccc;border:0;margin:1.2em 0">
<h1 style='font-family:"Trebuchet MS", Verdana, sans-serif;margin:0px;font-size:1.3em;line-height:1.4em'><a href="http://localhost:3000/issues/1#change-2" style="color:#169">Bug #1: Cannot print recipes</a></h1>

<ul class="details" style="color:#959595;margin-bottom:1.5em"><li><strong>Author: </strong>John Smith</li>
<li><strong>Status: </strong>New</li>
<li><strong>Priority: </strong></li>
<li><strong>Assignee: </strong></li>
<li><strong>Category: </strong></li>
<li><strong>Target version: </strong></li></ul>

<p>Unable to print recipes</p>



<hr style="width:100%;height:1px;background:#ccc;border:0;margin:1.2em 0">
<span class="footer" style="font-size:0.8em;font-style:italic"><p>You have received this notification because you have either subscribed to it, or are involved in it.<br>To change your notification preferences, please click here: <a class="external" href="http://hostname/my/account" style="color:#169">http://hostname/my/account</a></p></span>
</body>
</html>
    HTML_MAIL
  end
end
