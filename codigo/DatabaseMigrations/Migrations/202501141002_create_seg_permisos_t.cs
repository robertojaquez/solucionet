using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141002)]
	public class _202501141002_create_seg_permisos_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_permisos_t.sql");
		}

		public override void Down()
		{
		}
	}
}
