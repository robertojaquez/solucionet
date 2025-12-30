using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141108)]
	public class _202501141108_insert_into_man_mensajes_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_man_mensajes_t.sql");
		}

		public override void Down()
		{
		}
	}
}
