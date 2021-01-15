public class flesh_mask extends EntityModel<Entity> {
	private final ModelRenderer bone;

	public flesh_mask() {
		textureWidth = 16;
		textureHeight = 16;

		bone = new ModelRenderer(this);
		bone.setRotationPoint(0.0F, 24.0F, 0.0F);
		bone.setTextureOffset(0, 0).addBox(-14.0F, -14.0F, 2.0F, 13.0F, 13.0F, 0.0F, 0.0F, false);
		bone.setTextureOffset(0, 16).addBox(-1.0F, -14.0F, 2.0F, 0.0F, 13.0F, 3.0F, 0.0F, false);
		bone.setTextureOffset(13, 16).addBox(-14.0F, -14.0F, 2.0F, 0.0F, 13.0F, 3.0F, 0.0F, false);
		bone.setTextureOffset(0, 16).addBox(-14.0F, -1.0F, 2.0F, 13.0F, 0.0F, 3.0F, 0.0F, false);
		bone.setTextureOffset(0, 16).addBox(-14.0F, -14.0F, 2.0F, 13.0F, 0.0F, 3.0F, 0.0F, false);
	}

	@Override
	public void setRotationAngles(Entity entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch){
		//previously the render function, render code was moved to a method below
	}

	@Override
	public void render(MatrixStack matrixStack, IVertexBuilder buffer, int packedLight, int packedOverlay, float red, float green, float blue, float alpha){
		bone.render(matrixStack, buffer, packedLight, packedOverlay);
	}

	public void setRotationAngle(ModelRenderer modelRenderer, float x, float y, float z) {
		modelRenderer.rotateAngleX = x;
		modelRenderer.rotateAngleY = y;
		modelRenderer.rotateAngleZ = z;
	}
}