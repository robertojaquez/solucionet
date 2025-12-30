using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141107)]
	public class _202501141107_insert_into_seg_permisos_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_seg_permisos_t.sql");
		}

		public override void Down()
		{
		}
	}
}
