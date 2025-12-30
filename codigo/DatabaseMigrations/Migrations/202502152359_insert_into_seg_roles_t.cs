using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
    [Migration(202502152359)]
    public class _202502152359_insert_into_seg_roles_t : FluentMigrator.Migration
    {
        public override void Up()
        {
            Execute.Script("insert_into_seg_roles_t.sql");
        }

        public override void Down()
        {
        }
    }
}