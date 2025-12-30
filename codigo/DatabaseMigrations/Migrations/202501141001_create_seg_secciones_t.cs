using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141001)]
	public class _202501141001_create_seg_secciones_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_secciones_t.sql");
		}

		public override void Down()
		{
		}
	}
}
