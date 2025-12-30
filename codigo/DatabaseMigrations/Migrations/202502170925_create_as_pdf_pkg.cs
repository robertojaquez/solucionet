using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
    [Migration(202502170925)]
    public class _202502170925_create_as_pdf_pkg : FluentMigrator.Migration
    {
        public override void Up()
        {
            Execute.Script("as_pdf_spec_pkg.sql");
            Execute.Script("as_pdf_body_pkg.sql");
        }

        public override void Down()
        {
        }
    }
}