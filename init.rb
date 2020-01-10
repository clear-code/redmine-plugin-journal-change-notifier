Redmine::Plugin.register :journal_change_notifier do
  name "Journal Change Notifier plugin"
  author "Kouhei Sutou"
  description "Notify journal change by e-mail"
  version "1.0.1"
  url "https://github.com/clear-code/redmine-plugin-journal-change-notifier"
  author_url "https://github.com/kou/"
end

require "diff/lcs"
require "diff/lcs/hunk"

class JournalChangeMailer < Mailer
  class << self
    def deliver_journal_edit(changer, journal)
      if Redmine::VERSION::MAJOR >= 4
        deliver_journal_edit_latest(changer, journal)
      else
        deliver_journal_edit_v3(changer, journal)
      end
    end

    private
    def deliver_journal_edit_latest(changer, journal)
      users = journal.notified_users | journal.notified_watchers
      users.select! do |user|
        journal.notes? || journal.visible_details(user).any?
      end
      users.each do |user|
        mail = journal_edit(changer, journal, to: user)
        mail.deliver
      end
    end

    def deliver_journal_edit_v3(changer, journal)
      issue = journal.journalized.reload
      to = journal.notified_users
      cc = journal.notified_watchers
      journal.each_notification(to + cc) do |users|
        issue.each_notification(users) do |users2|
          mail = journal_edit(changer,
                              journal,
                              to: to & users2,
                              cc: cc & users2)
          mail.deliver
        end
      end
    end
  end

  def journal_edit(changer, journal, options)
    if options.key?(:cc)
      journal_edit_v3(changer, journal, options[:to], options[:cc])
    else
      journal_edit_latest(changer, journal, options[:to])
    end
  end

  private
  def journal_edit_latest(changer, journal, user)
    issue = journal.journalized
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    message_id journal
    references issue
    @author = changer
    @changer = changer
    s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
    s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
    s << issue.subject
    @issue = issue
    @user = user
    @users = [user]
    @journal = journal
    @journal_details = journal.visible_details(user)
    @issue_url = url_for(:controller => 'issues',
                         :action => 'show',
                         :id => issue,
                         :anchor => "change-#{journal.id}")
    mail(:to => user.mail,
         :subject => s)
  end

  def journal_edit_v3(changer, journal, to_users, cc_users)
    issue = journal.journalized
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    message_id journal
    references issue
    @changer = changer
    s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
    s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
    s << issue.subject
    @issue = issue
    @users = to_users + cc_users
    @user = @users.first
    @journal = journal
    @journal_details = journal.visible_details(@users.first)
    @issue_url = url_for(:controller => 'issues',
                         :action => 'show',
                         :id => issue,
                         :anchor => "change-#{journal.id}")
    mail(:to => to_users.map(&:mail),
         :cc => cc_users.map(&:mail),
         :subject => s)
  end
end

class JournalChangeDiffer
  def initialize(journal)
    @journal = journal
  end

  def diff
    from, to, = @journal.previous_changes["notes"]
    unified_diff(from, to)
  end

  private
  def unified_diff(content_from, content_to)
    to_lines = content_to.lines.collect(&:chomp)
    from_lines = content_from.lines.collect(&:chomp)
    diffs = ::Diff::LCS.diff(from_lines, to_lines)

    unified_diff = ""

    old_hunk = nil
    n_lines = 3
    format = :unified
    file_length_difference = 0
    diffs.each do |piece|
      begin
        hunk = ::Diff::LCS::Hunk.new(from_lines, to_lines, piece, n_lines,
                                     file_length_difference)
        file_length_difference = hunk.file_length_difference

        next unless old_hunk

        if (n_lines > 0) and hunk.overlaps?(old_hunk)
          hunk.merge(old_hunk)
        else
          unified_diff << old_hunk.diff(format)
        end
      ensure
        old_hunk = hunk
        unified_diff << "\n"
      end
    end

    if old_hunk
      unified_diff << old_hunk.diff(format)
      unified_diff << "\n"
    end
    unified_diff
  end
end

class JournalDiffNotifyListener < Redmine::Hook::Listener
  def controller_journals_edit_post(context)
    journal = context[:journal]
    if Redmine::VERSION::MAJOR >= 4
      return unless journal.notes_previously_changed?
    else
      return unless journal.previous_changes.key?("notes")
    end
    JournalChangeMailer.deliver_journal_edit(User.current, journal)
  end
end
