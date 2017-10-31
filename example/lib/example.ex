defmodule Example do

  defmodule LayoutView do
    use Phoenix.View, root: "../test/support/templates/layout", namespace: Bamboo.LayoutView
  end

  defmodule EmailView do
    use Phoenix.View, root: "../test/support/templates/email", namespace: Bamboo.EmailView
  end

  defmodule Emails do
    use Bamboo.PhoenixMjml, view: EmailView

    def text_and_html_email_with_layout do
      new_email()
      |> put_layout({LayoutView, :app})
      |> render(:text_and_html_email)
    end

    def text_and_html_email do
      new_email()
      |> render(:text_and_html_email)
    end

    def email_with_assigns(user) do
      new_email()
      |> render(:email_with_assigns, user: user)
    end

    def email_with_already_assigned_user(user) do
      new_email()
      |> assign(:user, user)
      |> render(:email_with_assigns)
    end

    def html_email do
      new_email
      |> render("html_email.html.mjml")
    end

    def text_email do
      new_email
      |> render("text_email.text")
    end

    def no_template do
      new_email
      |> render(:non_existent)
    end

    def invalid_template do
      new_email
      |> render("template.foobar")
    end
  end
end
